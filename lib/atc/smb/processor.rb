# frozen_string_literal: true

require 'digest'

class Atc::Smb::Processor
  def initialize(source_dir, destination_bucket = nil)
    @source_dir = source_dir
    # @destination_bucket = destination_bucket
    @destination_bucket = SMB_CONFIG[:destination_bucket]
    @connector = Atc::Smb::Connector.new
    @csv_writer = Atc::Smb::CsvWriter.new
    @uploader = Atc::Smb::BagUploader.new(@destination_bucket) # use the arg
  end

  def run
    # 1. Read from the source directory and log every file into a CSV
    add_source_files_to_csv
    # 2. Normalize the source paths so that they are suitable for uploading
    normalize_source_paths
    # 3. Download and process the files (one at a time)
    download_and_process_source_files
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
    files = @csv_writer.each_normalized_file

    @connector.each_downloaded_file(@source_dir, files) do |local_path, normalized_path, size|
      # Generated from the downloaded file, in the same form the BagIt manifest needs
      checksum = Digest::SHA256.file(local_path).hexdigest
      puts "Checksum for #{normalized_path}: #{checksum}"
      @uploader.upload_file(local_path, "#{bag_root}/data/#{normalized_path}")
      # TODO: After the upload is successful, record the file path and its checksum in the manifest file
      puts "File #{normalized_path} uploaded successfully, checksum: #{checksum}, size: #{size}"
    end
  end

  # Temp: assumes the file is already downloaded and CSV contains its info; doesn't connect to SMB server
  # so the upload can be tested locally
  def upload_files
    files = @csv_writer.each_normalized_file
    files.each do |file_path, normalized_path, size|
      puts "Preparing to upload file #{normalized_path}, size: #{size}, source path #{file_path}"

      local_path = File.join(SMB_CONFIG[:stabilization_dir], normalized_path)
      puts "Local path #{local_path}"
      @uploader.upload_file(local_path, "#{bag_root}/data/#{normalized_path}")
      # puts "File #{normalized_path} uploaded successfully"
    end
  end

  # The root level of the bag is normalized and might not match the original source directory's name
  def bag_root
    @bag_root ||= Atc::Utils::ObjectKeyNameUtils.remediate_key_name(File.basename(@source_dir))
  end
end
