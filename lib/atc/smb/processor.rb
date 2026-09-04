# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'securerandom'

class Atc::Smb::Processor
  attr_reader :run_id, :stabilization_dir

  # Takes an Atc::Smb::TaskArgs which holds the validated source directory and ingest bucket target
  def initialize(task_args)
    @source_config = task_args.source_config
    @source_dir = task_args.source_path
    @prefix = task_args.prefix
    @destination_bucket = SMB_CONFIG[:destination_bucket]
    @run_id = SecureRandom.uuid
    @stabilization_dir = File.join(SMB_CONFIG[:stabilization_dir], @run_id)
    FileUtils.mkdir_p(@stabilization_dir)

    puts "Reading from //#{@source_config[:host]}/#{@source_config[:share]}#{@source_dir}"
    puts "Writing to s3://#{@destination_bucket}/#{prefixed_key(bag_root)}"
    puts "Files will be stored in the local stabilization directory: #{@stabilization_dir}"

    @connector = Atc::Smb::Connector.new(source_config: @source_config, stabilization_dir: @stabilization_dir)
    @csv_writer = Atc::Smb::CsvWriter.new(stabilization_dir: @stabilization_dir)
    @manifest_writer = Atc::Smb::ManifestWriter.new(stabilization_dir: @stabilization_dir)
    @uploader = Atc::Smb::BagUploader.new(@destination_bucket)
  end

  def run
    # TODO: Make sure that the destination bucket path doesn't exist
    # If it does, we want to make sure that the user is aware and wants to overwrite it

    # 1. Read from the source directory and log every file into a CSV
    add_source_files_to_csv
    # 1a. Check if any of the added files is above 100GB
    if check_large_files.any?
      body_content = check_large_files.join(', ')

      StabilizationMailer.with(
        to: SMB_CONFIG[:notification_email],
        subject: 'Large files detected',
        body_content: body_content
      ).send_mail.deliver
      return
    end

    # 2. Normalize the source paths so that they are suitable for uploading
    normalize_source_paths
    # 3. Download and process the files (one at a time)
    download_and_process_source_files
    # 4. Check for results of virus scanning, send BagIt files if no viruses found
    non_success_files = scan_files_and_report_results
    # 5. Assemble tag files and finalize the BagIt package, regardless of virus scan results
    assemble_final_files(non_success_files)
  end

  def add_source_files_to_csv
    @csv_writer.write_files(@connector.list_files(@source_dir))
  end

  def normalize_source_paths
    @csv_writer.normalize_paths
  end

  # Downloads each file that was not skipped, then generates checksum, uploads and records it
  # before moving on to the next one, so only one file is on local disk at a time
  def download_and_process_source_files
    @manifest_writer.start
    files = @csv_writer.each_normalized_file

    @connector.each_downloaded_file(@source_dir, files) do |local_path, normalized_path, size|
      # Generated from the downloaded file, in the same form the BagIt manifest needs
      checksum = Digest::SHA256.file(local_path).hexdigest
      puts "Checksum for #{normalized_path}: #{checksum}"
      @uploader.upload_file(local_path, object_key_for(normalized_path))
      puts "File #{normalized_path} uploaded successfully, checksum: #{checksum}, size: #{size}"
      @manifest_writer.add_row(checksum, normalized_path, size)
      
      # TODO: Delete the local file
    end

    puts "Payload-Oxum for manifest: #{@manifest_writer.payload_oxum}"
  end

  # Temp: assumes the file is already downloaded and CSV contains its info; doesn't connect to SMB server
  # so the upload can be tested locally
  def upload_files
    @manifest_writer.start
    files = @csv_writer.each_normalized_file

    files.each do |file_path, normalized_path, size|
      puts "Preparing to upload file #{normalized_path}, size: #{size}, source path #{file_path}"

      local_path = File.join(@stabilization_dir, normalized_path)
      puts "Local path #{local_path}"
      @uploader.upload_file(local_path, object_key_for(normalized_path))
      checksum = Digest::SHA256.file(local_path).hexdigest
      puts "File #{normalized_path} uploaded successfully, checksum: #{checksum}, size: #{size}"
      @manifest_writer.add_row(checksum, normalized_path, size)
    end

    puts "Payload-Oxum for manifest: #{@manifest_writer.payload_oxum}"
  end

  # Waits for GuardDuty to finish scanning every file uploaded and reports the outcome
  def scan_files_and_report_results
    checker = Atc::Smb::VirusScanChecker.new(@destination_bucket)
    puts "Waiting for virus scan results for #{uploaded_object_keys.size} file(s)..."
    # Files that never got a result stay as 'NOT SCANNED' so can still be reported as failures
    results = uploaded_object_keys.index_with('NOT SCANNED')

    checker.each_scan_result(uploaded_object_keys) do |object_key, status|
      puts "Scan result for #{object_key}: #{status}"
      results[object_key] = status
    end

    failures = results.reject { |key, status| status == 'NO_THREATS_FOUND' }
    report_scan_outcome(failures)
    failures
  end

  def report_scan_outcome(failures)
    if failures.empty?
      puts 'All files passed the virus scan'
    else
      puts "Some files didn't pass the virus scan:"
      failures.each do |object_key, status|
        puts "#{object_key}: #{status}"
      end
    end
  end

  # Writes the five BagIt tag files and uploads them to the top level of the bag
  def assemble_final_files(non_success_files)
    assembler = Atc::Smb::BagAssembler.new(
      source_dir: @source_dir,
      payload_oxum: @manifest_writer.payload_oxum,
      manifest_file: @manifest_writer.manifest_file,
      normalization_log_file: @csv_writer.csv_file,
      stabilization_dir: @stabilization_dir,
      non_success_files: non_success_files
    )
    assembler.write_tag_files

    assembler.tag_files.each do |file|
      object_key = prefixed_key(bag_root, File.basename(file))
      puts "Sending #{file} to #{object_key}"
      @uploader.upload_file(file, object_key)
    end
  end

  def uploaded_object_keys
    @uploaded_object_keys ||= @csv_writer.each_normalized_file.map do |_file_path, normalized_path, _size|
      object_key_for(normalized_path)
    end
  end

  def check_large_files
    large_files = []

    CSV.foreach(@csv_writer.csv_file, headers: true) do |row|
      skipped = row['skipped']
      size = row['size'].to_i
      next if skipped == 'SKIPPED'

      if size > 100.gigabytes
        puts "Warning: File #{row['file_path']} is larger than 100GB (#{size} bytes)"
        large_files << row['file_path']
      end
    end
    
    large_files
  end

  # The root level of the bag is normalized and might not match the original source directory's name
  def bag_root
    @bag_root ||= Atc::Utils::ObjectKeyNameUtils.remediate_key_name(File.basename(@source_dir))
  end

  def object_key_for(normalized_path)
    prefixed_key(bag_root, 'data', normalized_path)
  end

  # Builds an object key below the ingest bucket target which is empty when the target is the bucket root
  def prefixed_key(*segments)
    [@prefix, *segments].reject(&:blank?).join('/')
  end
end
