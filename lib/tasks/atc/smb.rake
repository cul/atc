namespace :atc do
  namespace :smb do
    desc "Test SMB connection"
     task test: :environment do
      # TODO: Validate environment variables
      # TODO: Will accept ingest_bucket_target=path/to/target/directory later
      remote_dir = ENV['source']

      processor = Atc::Smb::Processor.new(remote_dir)
      processor.add_source_files_to_csv
      puts "SMB connection test completed."
    end

    desc "Reads from CSV file"
    task normalize_paths: :environment do
      csv_writer = Atc::Smb::CsvWriter.new
      csv_writer.normalize_paths
    end

    task upload_files: :environment do
      remote_dir = ENV['source']
      processor = Atc::Smb::Processor.new(remote_dir)
      processor.download_and_process_source_files
    end
  end
end