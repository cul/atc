namespace :atc do
  namespace :stabilization do
    # Every task that starts with Processor invocation requires the following environment variables:
    #   source_type=ldrive                     A configured source drive (see the sources section of stabilization.template.yml)
    #   source_path=/existing-dir/subdir       The directory to stabilize on the source drive
    #   repository_name=RBML                   The repository name that will be logged in bag-info.txt; used for assembling name of the bag
    #   collection_name=David Byrne Papers     The collection name that will be logged in bag-info.txt; used for assembling name of the bag
    def task_args
      @task_args ||= Atc::Stabilization::TaskArgs.from_env
    rescue ArgumentError => e
      abort Rainbow(e.message).red
    end

    # Memoized because every Processor creates its a timestamped run directory
    def processor
      @processor ||= Atc::Stabilization::Processor.new(
        source_path: task_args.source_path,
        source_type: task_args.source_type,
        repository_name: task_args.repository_name,
        collection_name: task_args.collection_name,
        bag_name: task_args.bag_name
      )
    end

    def describe_run
      puts Rainbow("This process will copy files from #{Rainbow(task_args.source_path).yellow.bold} on the #{Rainbow(task_args.source_type).yellow.bold} to a newly created #{Rainbow(task_args.bag_name).yellow.bold} directory in the stabilization bucket.")
    end

    # Downloads the finalized bag from the stabilization bucket and validates it
    def retrieve_bag(bag_root_prefix)
      retrieved = Atc::Stabilization::BagRetriever.new(
        bucket: STABILIZATION_CONFIG[:stabilization_bucket],
        bag_root_prefix: bag_root_prefix,
        # download_dir:STABILIZATION_CONFIG[:cul_volume_download_dir] # this will be used in prod
        download_dir: STABILIZATION_CONFIG[:work_dir]
      ).retrieve

      abort Rainbow('Could not retrieve a valid bag (see the reason above).').red unless retrieved
    end

    desc 'Run the full stabilization process'
    task run: :environment do
      describe_run
      success, s3_uri = processor.run

      unless success
        message = 'The stabilization process did not complete successfully, so the bag was not downloaded.'
        message += " The bag is available at #{s3_uri} for investigation." if s3_uri
        abort Rainbow(message).red
      end

      puts Rainbow("The bag was uploaded to #{s3_uri}").green
      retrieve_bag(task_args.bag_name)
    rescue Atc::Exceptions::SourceListingError => e
      abort Rainbow("Could not read the source directory: #{e.message}").red
    end

    desc 'Download a finalized bag from the stabilization bucket and validate it'
    task download_finalized_bag: :environment do
      bag_name = ENV['bag_name']
      abort Rainbow('Missing required argument: bag_name=repository_collection_YYYYMMDD_HHMMSS').red if bag_name.blank?

      retrieve_bag(bag_name)
    end

    ################################
    # Below are individual tasks for testing and running specific parts of the SMB stabilization process.
    # Running these individually might result in an incomplete stabilization process.
    # Use it for testing and debugging purposes only.
    ################################
    desc 'Lists the source directory into a CSV'
    task create_file_inventory: :environment do
      processor.add_source_files_to_csv
      puts 'Added source files to CSV'
    end

    desc 'Normalizes the paths in the CSV file'
    task normalize_paths: :environment do
      processor.normalize_source_paths
    end

    desc 'Download each source file and upload it to the ingest bucket'
    task upload_files: :environment do
      processor.download_and_process_source_files
    end

    # Assumes CSV file already contains the list of files to upload and those files
    # are present in the local stabilization directory
    # desc 'Upload files that are already present in the local stabilization directory'
    # task test_upload: :environment do
    #   processor.upload_files
    # end

    desc 'Wait for virus scan results for the uploaded files and report the outcome'
    task get_scanning_results: :environment do
      processor.scan_files_and_report_results
    end

    desc 'Report any source files larger than 100GB'
    task large_files: :environment do
      large_files = processor.check_large_files

      if large_files.any?
        puts "Some files are larger than 100GB: #{large_files.join(', ')}"
        StabilizationMailer.notify('Large files detected', large_files.join(', '))
      end
    end

    desc 'Write the BagIt tag files and upload them to the top level of the bag'
    task assemble_files: :environment do
      processor.assemble_final_files(virus_check_passed: true)
    end
  end
end
