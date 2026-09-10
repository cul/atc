# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'securerandom'

class Atc::Smb::Processor
  attr_reader :run_id, :stabilization_dir

  # Takes an Atc::Smb::TaskArgs which holds the validated source directory and ingest bucket target
  def initialize(task_args)
    @source_config = task_args.source_config
    
    # Path to the source directory we're syncing from
    @source_dir = task_args.source_path

    # The bag will be uploaded to the root of the stabilization bucket
    @stabilization_bucket = SMB_CONFIG[:stabilization_bucket]
    @stabilization_root = task_args.stabilization_path

    # Where the bag will eventually go in the ingest bucket (not yet implemented)
    @ingest_bucket = SMB_CONFIG[:ingest_bucket]
    @ingest_root = task_args.ingest_path

    @run_id = SecureRandom.uuid
    @stabilization_dir = File.join(SMB_CONFIG[:stabilization_dir], @run_id) # Needs a better name
    FileUtils.mkdir_p(@stabilization_dir)

    puts "Reading from //#{@source_config[:host]}/#{@source_config[:share]}#{@source_dir}"
    puts "Writing to s3://#{@stabilization_bucket}/#{@stabilization_root}"
    puts "Later sending to s3://#{@ingest_bucket}/#{@ingest_root}"
    puts "Files will be stored in the local stabilization directory: #{@stabilization_dir}"

    @connector = Atc::Smb::Connector.new(source_config: @source_config, stabilization_dir: @stabilization_dir)
    @csv_writer = Atc::Smb::CsvWriter.new(stabilization_dir: @stabilization_dir)
    @manifest_writer = Atc::Smb::ManifestWriter.new(stabilization_dir: @stabilization_dir)
    @uploader = Atc::Smb::BagUploader.new(@stabilization_bucket)
    @ingest_uploader = Atc::Smb::BagUploader.new(@ingest_bucket)
  end

  def run
    # TODO: If directories exist, present 2 options:
    # 1. Rename the target path
    # 2. Accept an overwrite flag
    existing_path = check_if_directories_exist
    abort "Path already exists: #{existing_path}" if existing_path

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
    # 4. Check for results of virus scanning and record them in the CSV
    failures = scan_files_and_report_results
    # 5. Assemble tag files and finalize the BagIt package, regardless of virus scan results
    assemble_final_files(virus_check_passed: failures.empty?)
    # 6. If everything was successful, download the finalized bag
    # download_and_validate_bag
  end

  def check_if_directories_exist
    destinations = [
      [@stabilization_root, @uploader],
      [@ingest_root, @ingest_uploader]
    ]

    destinations.each do |dir, uploader|
      puts "Checking if directory exists: #{dir}"
      return "s3://#{uploader.bucket_name}/#{dir}" if uploader.directory_exists(dir)
    end

    nil
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

  # Waits for GuardDuty to finish scanning every file uploaded and records the outcome in the CSV
  def scan_files_and_report_results
    checker = Atc::Smb::VirusScanChecker.new(@stabilization_bucket)
    puts "Waiting for virus scan results for #{normalized_paths_by_object_key.size} file(s)..."
    # Files that never got a result stay as 'NOT SCANNED' so can still be reported as failures
    results = normalized_paths_by_object_key.values.index_with('NOT SCANNED')

    checker.each_scan_result(normalized_paths_by_object_key.keys) do |object_key, status|
      puts "Scan result for #{object_key}: #{status}"
      results[normalized_paths_by_object_key[object_key]] = status
    end

    @csv_writer.write_scan_results(results)

    failures = results.reject { |_normalized_path, status| status == 'NO_THREATS_FOUND' }
    report_scan_outcome(failures)
    failures
  end

  def report_scan_outcome(failures)
    if failures.empty?
      puts 'All files passed the virus scan'
    else
      puts "Some files didn't pass the virus scan:"
      failures.each do |normalized_path, status|
        puts "#{normalized_path}: #{status}"
      end
    end
  end

  # Writes the five BagIt tag files and uploads them to the top level of the bag
  def assemble_final_files(virus_check_passed:)
    assembler = Atc::Smb::BagAssembler.new(
      source_dir: @source_dir,
      payload_oxum: @manifest_writer.payload_oxum,
      manifest_file: @manifest_writer.manifest_file,
      normalization_log_file: @csv_writer.csv_file,
      stabilization_dir: @stabilization_dir,
      virus_check_passed: virus_check_passed,
      ingest_bucket_path: @ingest_root
    )
    assembler.write_tag_files

    assembler.tag_files.each do |file|
      object_key = stabilization_key(File.basename(file))
      puts "Sending #{file} to #{object_key}"
      @uploader.upload_file(file, object_key)
    end
  end

  # TODO: Move to a separate class and clean up
  def download_and_validate_bag
    # 1. Check if there is same-name directory at the target cul path, name it after stabilization root

    # download_dir = File.join(SMB_CONFIG[:cul_volume_download_dir], stabilization_key) # this will be used on the server
    final_bag_path = File.join(SMB_CONFIG[:stabilization_dir], stabilization_key)
    parent_path = SMB_CONFIG[:stabilization_dir]
    puts "Downloading to #{parent_path}"

    if Dir.exist?(final_bag_path)
      StabilizationMailer.with(
        to: SMB_CONFIG[:notification_email],
        subject: "Couldn't download bag",
        body_content: "The directory #{final_bag_path} already exists."
      ).send_mail.deliver
      throw "Target directory #{final_bag_path} already exists."
    end

    # 2. Download the finalized bag from the ingest bucket to the local stabilization directory
    # The directory will be downloaded as its basename under the parent path
    s3_downloader = Atc::Aws::S3Downloader.new(@stabilization_bucket, parent_path)
    s3_downloader.download_directory(stabilization_key)

    # 3. Validate the bag (e.g., check for the presence of all expected files and tag files)
    puts "Checking downloaded bag under #{final_bag_path}"
    bag = BagIt::Bag.new(final_bag_path)
    puts "Bag is #{bag}"

    if bag.valid?
      puts "#{final_bag_path} is valid"
      StabilizationMailer.with(
        to: SMB_CONFIG[:notification_email],
        subject: "Successfully downloaded bag",
        body_content: "The bag was successfully downloaded to #{final_bag_path}."
      ).send_mail.deliver
      # TODO: Delete the bag from AWS stabilization directory
    else
      puts "#{final_bag_path} is not valid"
      StabilizationMailer.with(
        to: SMB_CONFIG[:notification_email],
        subject: "Failed to download bag",
        body_content: "The bag downloaded to #{final_bag_path} is not valid."
      ).send_mail.deliver
    end
  end

  # Maps the object key of every uploaded file to its normalized path so we can record a scan
  # result in a CSV file
  def normalized_paths_by_object_key
    @normalized_paths_by_object_key ||= @csv_writer.each_normalized_file.to_h do |_path, normalized_path, _size|
      object_key = object_key_for(normalized_path)
      puts "Object key for #{normalized_path} is #{object_key}"
      [object_key, normalized_path]
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

  def object_key_for(normalized_path)
    stabilization_key('data', normalized_path)
  end

  def stabilization_key(*segments)
    [@stabilization_root, *segments].join('/')
  end
end
