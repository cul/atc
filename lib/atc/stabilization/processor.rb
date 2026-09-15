# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'securerandom'

class Atc::Stabilization::Processor
  attr_reader :run_id, :run_dir

  def initialize(source_path:, source_type:, repository_name:, collection_name:, bag_name:)
    # Path to the source directory we're syncing from
    @source_dir = source_path

    # The bag will be uploaded to the root of the stabilization bucket
    @stabilization_bucket = STABILIZATION_CONFIG[:stabilization_bucket]
    @repository_name = repository_name
    @collection_name = collection_name
    # The layout object helps determine the structure of the bag within the stabilization bucket
    puts "Passing bag name to layout: #{bag_name}"
    @layout = Atc::Bag::Layout.new(bag_name)

    @run_id = SecureRandom.uuid
    @work_dir = STABILIZATION_CONFIG[:work_dir]
    @run_dir = File.join(@work_dir, @run_id)
    FileUtils.mkdir_p(@run_dir)

    # source_type is validated by Atc::Stabilization::TaskArgs which currently only implements ldrive
    @connector = Atc::Smb::Connector.new
    @inventory = Atc::Stabilization::Inventory.new(run_dir: @run_dir)
    @payload_manifest = Atc::Bag::PayloadManifest.new(bag_dir: @run_dir, layout: @layout)
    @uploader = Atc::Stabilization::BagUploader.new(@stabilization_bucket)

    puts "Reading from #{@connector.smb_address}#{@source_dir}"
    puts "Writing to s3://#{@stabilization_bucket}/#{@layout.bag_root_prefix}"
    puts "Files will be stored in the local stabilization directory: #{@run_dir}"
  end

  def run
    # Safeguard against overwriting an existing stabilization directory. With the current implementation,
    # this should never happen because each stabilization directory contains a YYYYMMDD_HHMMSS timestamp.
    abort "Path already exists: #{@layout.bag_root_prefix}" if stabilization_directory_exists?

    # 1. Read from the source directory and log every file into a CSV
    add_source_files_to_csv
    # 1a. Check if any of the added files is above 100GB
    large_files = check_large_files
    if large_files.any?
      StabilizationMailer.with(
        to: STABILIZATION_CONFIG[:notification_email],
        subject: 'Large files detected',
        body_content: large_files.join(', ')
      ).send_mail.deliver
      return
    end

    # 2. Normalize the source paths so that they are suitable for uploading
    normalize_source_paths
    puts "Done normalizing; check #{work_dir} for results"
    return
    # 3. Download and process the files (one at a time)
    download_and_process_source_files
    # 4. Check for results of virus scanning and record them in the CSV
    failures = scan_files_and_report_results
    # 5. Assemble tag files and finalize the BagIt package, regardless of virus scan results
    assemble_final_files(virus_check_passed: failures.empty?)
    
    # TODO: Move this step outside of Processor
    # 6. If everything was successful, download the finalized bag
    download_and_validate_bag
  end

  def stabilization_directory_exists?
    @uploader.directory_exists(@layout.bag_root_prefix)
  end

  def add_source_files_to_csv
    @inventory.write_files(@connector.list_files(@source_dir))
  end

  def normalize_source_paths
    @inventory.normalize_paths
  end

  # Downloads each file that was not skipped, then generates checksum, uploads and records it
  # before moving on to the next one, so only one file is on local disk at a time
  def download_and_process_source_files
    @payload_manifest.start

    @inventory.each_transferable.with_index do |entry, index|
      normalized_path = entry.normalized_path
      local_path = @connector.download_file(
        @source_dir, entry.file_path, staging_path(index, normalized_path), expected_size: entry.size
      )
      # Generated from the downloaded file, in the same form the BagIt manifest needs
      checksum = Digest::SHA256.file(local_path).hexdigest
      puts "Checksum for #{normalized_path}: #{checksum}"
      @uploader.upload_file(local_path, @layout.payload_object_key(normalized_path))
      puts "File #{normalized_path} uploaded successfully, checksum: #{checksum}, size: #{entry.size}"
      @payload_manifest.add_row(checksum, normalized_path, entry.size)

      # TODO: Delete the local file
    end

    puts "Payload-Oxum for manifest: #{@payload_manifest.payload_oxum}"
  end

  # Files are written to the root of the run directory for easier cleanup (no empty directories)
  # and to avoid running past filesystem's length limit.
  def staging_path(index, normalized_path)
    file_number = (index + 1).to_s.rjust(6, '0')
    File.join(@run_dir, "#{file_number}#{File.extname(normalized_path)}")
  end

  # Waits for GuardDuty to finish scanning every file uploaded and records the outcome in the CSV
  def scan_files_and_report_results
    checker = Atc::Aws::VirusScanChecker.new(@stabilization_bucket) # TODO: Move to initializer
    puts "Waiting for virus scan results for #{normalized_paths_by_object_key.size} file(s)..."
    # Files that never got a result stay as 'NOT SCANNED' so can still be reported as failures
    results = normalized_paths_by_object_key.values.index_with('NOT SCANNED')

    checker.each_scan_result(normalized_paths_by_object_key.keys) do |object_key, status|
      puts "Scan result for #{object_key}: #{status}"
      results[normalized_paths_by_object_key[object_key]] = status
    end

    @inventory.record_scan_results(results)

    failures = results.reject { |_normalized_path, status| status == 'NO_THREATS_FOUND' }
    report_scan_outcome(failures)
    failures
  end

  # TODO: In addition to logging to the console, send a notification email
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
    tag_file_writer = Atc::Bag::TagFileWriter.new(
      source_dir: @source_dir,
      payload_oxum: @payload_manifest.payload_oxum,
      manifest_file: @payload_manifest.manifest_file,
      inventory_file: @inventory.csv_file,
      bag_dir: @run_dir,
      virus_check_passed: virus_check_passed,
      repository_name: @repository_name,
      collection_name: @collection_name
    )
    tag_file_writer.write_tag_files

    tag_file_writer.tag_files.each do |file|
      object_key = @layout.tag_file_object_key(file)
      puts "Sending #{file} to #{object_key}"
      @uploader.upload_file(file, object_key)
    end
  end

  # TODO: Move to a separate class and clean up
  def download_and_validate_bag
    # 1. Check if there is same-name directory at the target cul path, name it after stabilization root

    # download_dir = File.join(STABILIZATION_CONFIG[:cul_volume_download_dir], @layout.bag_root_prefix) # this will be used on the server    
    final_bag_path = File.join(STABILIZATION_CONFIG[:work_dir], @layout.bag_root_prefix)
    parent_path = STABILIZATION_CONFIG[:work_dir]
    puts "Downloading to #{parent_path}"

    if Dir.exist?(final_bag_path)
      StabilizationMailer.with(
        to: STABILIZATION_CONFIG[:notification_email],
        subject: "Couldn't download bag",
        body_content: "The directory #{final_bag_path} already exists."
      ).send_mail.deliver
      raise "Target directory #{final_bag_path} already exists."
    end

    # 2. Download the finalized bag from the stabilization bucket to the local work directory
    # The directory will be downloaded as its basename under the parent path
    s3_downloader = Atc::Aws::S3Downloader.new(@stabilization_bucket, parent_path)
    s3_downloader.download_directory(@layout.bag_root_prefix)

    # 3. Validate the bag (e.g., check for the presence of all expected files and tag files)
    puts "Checking downloaded bag under #{final_bag_path}"
    validator = Atc::Bag::Validator.new(final_bag_path)

    if validator.valid?
      puts "#{final_bag_path} is valid"
      StabilizationMailer.with(
        to: STABILIZATION_CONFIG[:notification_email],
        subject: 'Successfully downloaded bag',
        body_content: "The bag was successfully downloaded to #{final_bag_path}."
      ).send_mail.deliver
      # TODO: Delete the bag from AWS stabilization directory
    else
      puts "#{final_bag_path} is not valid:"
      validator.errors.each { |error| puts error }
      StabilizationMailer.with(
        to: STABILIZATION_CONFIG[:notification_email],
        subject: 'Failed to download bag',
        body_content: "The bag downloaded to #{final_bag_path} is not valid:\n#{validator.errors.join("\n")}"
      ).send_mail.deliver
    end
  end

  # Maps the object key of every uploaded file to its normalized path so we can record a scan
  # result in a CSV file
  def normalized_paths_by_object_key
    # TODO: Add types
    @normalized_paths_by_object_key ||= @inventory.each_transferable.to_h do |entry|
      object_key = @layout.payload_object_key(entry.normalized_path)
      puts "Object key for #{entry.normalized_path} is #{object_key}"
      [object_key, entry.normalized_path]
    end
  end

  def check_large_files
    @inventory.oversized.map do |entry|
      puts "Warning: File #{entry.file_path} is larger than 100GB (#{entry.size} bytes)"
      entry.file_path
    end
  end
end
