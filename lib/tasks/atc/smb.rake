namespace :atc do
  namespace :smb do
    desc "Test SMB connection"
     task test: :environment do
      # TODO: Validate environment variables
      # TODO: Will accept ingest_bucket_target=path/to/target/directory later
      remote_dir = ENV['source']

      connector = Atc::Smb::Connector.new
      connector.list(remote_dir)
      puts "SMB connection test completed."
    end

    desc "Reads from CSV file"
    task normalize_paths: :environment do
      connector = Atc::Smb::Connector.new
      connector.normalize_paths
    end

    task upload_files: :environment do
      remote_dir = ENV['source']
      connector = Atc::Smb::Connector.new
      connector.get_and_upload_files(remote_dir)
    end
  end
end