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

    # Assumes CSV file already contains the list of files to upload and those files
    # are present in the local stabilization directory
    task test_upload: :environment do
      remote_dir = ENV['source']
      processor = Atc::Smb::Processor.new(remote_dir)
      processor.upload_files
    end

    task get_scanning_results: :environment do
      remote_dir = ENV['source']
      processor = Atc::Smb::Processor.new(remote_dir)
      processor.scan_files_and_report_results
    end

    task large_files: :environment do
      remote_dir = ENV['source']
      processor = Atc::Smb::Processor.new(remote_dir)
      large_files = processor.check_large_files

      if large_files.any?
        puts "Some files are larger than 100GB: #{large_files.join(', ')}"
        
        StabilizationMailer.with(
          to: SMB_CONFIG[:notification_email],
          subject: 'Large files detected',
          body_content: large_files.join(', ')
        ).send_mail.deliver
      end
    end

    task assemble_files: :environment do
      remote_dir = ENV['source']
      processor = Atc::Smb::Processor.new(remote_dir)
      processor.assemble_final_files
    end
  end
end