namespace :atc do
  namespace :smb do
    desc "Test SMB connection"
     task test: :environment do
      # TODO: Validate environment variables
      remote_dir = ENV['source']

      connector = Atc::Smb::Connector.new
      connector.list(remote_dir)
      puts "SMB connection test completed."
    end
  end
end