namespace :atc do
  namespace :stabilization do
    # Every task that starts with Processor invocation requires the following environment variables:
    #   source=L:/existing-dir/subdir          A configured source drive (see the sources section of stabilization.template.yml)
    #                                          followed by the directory to stabilize
    #   ingest_bucket_target=folder1/folder2   Where the bag goes within the ingest bucket. Also used to name 
    #                                          the bag at the root of the stabilization bucket, using a hyphenated form 
    #                                          of the ingest bucket target.
    def task_args
      @task_args ||= Atc::Stabilization::TaskArgs.from_env
    rescue ArgumentError => e
      abort Rainbow(e.message).red
    end

    # TODO: Should also accept source_type
    desc 'Run the full stabilization process'
    task run: :environment do
      puts Rainbow("This process will copy files from #{Rainbow(task_args.source_path).yellow.bold} on the #{Rainbow(task_args.source_type).yellow.bold} to a newly created #{Rainbow(task_args.bag_name).yellow.bold} directory in the stabilization bucket.")

      # Upon success:
      # success = true, s3_uri = 'S3 URI of the bag in the stabilization bucket'
      # Upon failure:
      # success = false, s3_uri = nil
      Atc::Stabilization::Processor.new(
        source_path: task_args.source_path,
        source_type: task_args.source_type,
        repository_name: task_args.repository_name,
        collection_name: task_args.collection_name,
        bag_name: task_args.bag_name
      ).run
      return
      # success, s3_uri = Atc::Stabilization::Processor.new(
      #   source_path: task_args.source_path,
      #   source_type: task_args.source_type,
      #   repository_name: task_args.repository_name,
      #   collection_name: task_args.collection_name
      # ).run

      # Download to CUL1 and validate completed bag
    end

    task check_directories: :environment do
      puts Rainbow("This process will copy files from #{Rainbow(task_args.source_path).yellow.bold} on the #{Rainbow(task_args.source_type).yellow.bold} to a newly created #{Rainbow(task_args.bag_name).yellow.bold} directory in the stabilization bucket.")
      processor = Atc::Stabilization::Processor.new(task_args)
      processor.check_if_directories_exist
    end


    ################################
    # Below are individual tasks for testing and running specific parts of the SMB stabilization process.
    # Running these individually might result in an incomplete stabilization process. 
    # Use it for testing and debugging purposes only.
    ################################
    desc 'Lists the source directory into a CSV'
    task create_file_inventory: :environment do
      Atc::Stabilization::Processor.new(task_args).add_source_files_to_csv
      puts 'Added source files to CSV'
    end

    desc 'Normalizes the paths in the CSV file'
    task normalize_paths: :environment do
      Atc::Stabilization::Processor.new(task_args).normalize_source_paths
    end

    desc 'Download each source file and upload it to the ingest bucket'
    task upload_files: :environment do
      Atc::Stabilization::Processor.new(task_args).download_and_process_source_files
    end

    # Assumes CSV file already contains the list of files to upload and those files
    # are present in the local stabilization directory
    # desc 'Upload files that are already present in the local stabilization directory'
    # task test_upload: :environment do
    #   Atc::Stabilization::Processor.new(task_args).upload_files
    # end

    desc 'Wait for virus scan results for the uploaded files and report the outcome'
    task get_scanning_results: :environment do
      Atc::Stabilization::Processor.new(task_args).scan_files_and_report_results
    end

    desc 'Report any source files larger than 100GB'
    task large_files: :environment do
      processor = Atc::Stabilization::Processor.new(task_args)
      large_files = processor.check_large_files

      if large_files.any?
        puts "Some files are larger than 100GB: #{large_files.join(', ')}"

        StabilizationMailer.with(
          to: STABILIZATION_CONFIG[:notification_email],
          subject: 'Large files detected',
          body_content: large_files.join(', ')
        ).send_mail.deliver
      end
    end

    desc 'Write the BagIt tag files and upload them to the top level of the bag'
    task assemble_files: :environment do
      Atc::Stabilization::Processor.new(task_args).assemble_final_files(virus_check_passed: true)
    end

    task download_finalized_bag: :environment do
      Atc::Stabilization::Processor.new(task_args).download_and_validate_bag
    end
  end
end
