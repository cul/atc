namespace :atc do
  namespace :smb do
    desc "Test SMB connection"
    task test: :environment do
      connector = Atc::Smb::Connector.new
      puts "SMB connection test completed."
    end
  end
end