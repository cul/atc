# frozen_string_literal: true

class Atc::Smb::Processor
  def initialize(source_dir, destination_bucket = nil)
    @source_dir = source_dir
    @destination_bucket = destination_bucket
    @connector = Atc::Smb::Connector.new
    @csv_writer = Atc::Smb::CsvWriter.new
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

  # Currently just downloads the files without any additional processing
  def download_and_process_source_files
    @connector.get_and_upload_files(@source_dir, @csv_writer.each_normalized_file)
  end
end
