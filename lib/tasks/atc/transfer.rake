namespace :atc do
  namespace :transfer do

    def source_directory_path_is_valid?(source_directory_path)
      if !File.exist?(source_directory_path)
        puts Rainbow("Error: Source directory not found at path: #{source_directory_path}").red.bright
        return false
      elsif source_directory_path.include?('//')
        puts Rainbow("Error: The source directory path you entered contains a double slash (//): #{source_directory_path}").red.bright
        return false
      elsif source_directory_path == '/'
        puts Rainbow("Error: Invalid source directory path: #{source_directory_path}").red.bright
        return false
      end

      true
    end

    desc 'Load files from a directory into ATC, generate checksums for those files, and initiate transfer and verification processes.'
    task directory: :environment do
      directory_path = ENV['directory_path']
      dry_run = ENV['dry_run'] == 'true'

      if directory_path.blank?
        puts Rainbow("Missing required argument: directory_path").red.bright
        next
      end
      next unless source_directory_path_is_valid?(directory_path)

      directory_reader = Atc::DirectoryReader.new(directory_path, verbose: true)

      # Iterate over files and load them into the ATC database (skipping files that already exist)
      source_object_counter = 0
      previously_inventoried_file_counter = 0

      print_inventory_addition_progress(source_object_counter, previously_inventoried_file_counter, dry_run)
      directory_reader.each_file do |file_path|
        unless dry_run
          size = File.size(file_path)
          source_object = SourceObject.create!(
            path: file_path,
            object_size: size
          )
          CreateFixityChecksumJob.perform_later(source_object.id, enqueue_successor: true)
        end
        source_object_counter += 1
        if source_object_counter % 1 == 0
          print_inventory_addition_progress(source_object_counter, previously_inventoried_file_counter, dry_run)
        end
      rescue ActiveRecord::RecordNotUnique => e
        # Skipping file because it was previously added to the inventory
        previously_inventoried_file_counter += 1
        if previously_inventoried_file_counter % 1 == 0
          print_inventory_addition_progress(source_object_counter, previously_inventoried_file_counter, dry_run)
        end
      end
      print_inventory_addition_progress(source_object_counter, previously_inventoried_file_counter, dry_run)
      puts "\nDone!"
    rescue Atc::Exceptions::DirectoryLoadError => e
      puts "An error has occurred (#{e.class.name}):\n" + Rainbow(e.message).red
    end

    desc 'Load files from an AIP into ATC, load checksums from the AIP manifest, and initiate transfer and verification processes.'
    task aip: :environment do
      aip_path = ENV['aip_path']
      dry_run = ENV['dry_run'] == 'true'

      if aip_path.blank?
        puts Rainbow("Missing required argument: aip_path").red.bright
        next
      end
      next unless source_directory_path_is_valid?(aip_path)

      aip_reader = Atc::AipReader.new(aip_path, verbose: true)

      # Identify checksum type for this AIP (sha256, sha512, or md5) and retrieve the associated ChecksumAlgorithm object
      fixity_checksum_algorithm = ChecksumAlgorithm.find_by(name: aip_reader.checksum_type.upcase)

      # Iterate over files and load them into the ATC database (skipping files that already exist)
      source_object_counter = 0
      previously_inventoried_file_counter = 0

      print_inventory_addition_progress(source_object_counter, previously_inventoried_file_counter, dry_run)
      aip_reader.each_file_with_checksum do |file_path, hex_checksum|
        unless dry_run
          size = File.size(file_path)
          source_object = SourceObject.create!(
            path: file_path,
            object_size: size,
            fixity_checksum_algorithm: fixity_checksum_algorithm,
            fixity_checksum_value: Atc::Utils::HexUtils.hex_to_bin(hex_checksum)
          )
          PrepareTransferJob.perform_later(source_object.id, enqueue_successor: true)
        end
        source_object_counter += 1
        if source_object_counter % 1 == 0
          print_inventory_addition_progress(source_object_counter, previously_inventoried_file_counter, dry_run)
        end
      rescue ActiveRecord::RecordNotUnique => e
        # Skipping file because it was previously added to the inventory
        previously_inventoried_file_counter += 1
        if previously_inventoried_file_counter % 1 == 0
          print_inventory_addition_progress(source_object_counter, previously_inventoried_file_counter, dry_run)
        end
      end
      print_inventory_addition_progress(source_object_counter, previously_inventoried_file_counter, dry_run)
      puts "\nDone!"
    rescue Atc::Exceptions::DirectoryLoadError => e
      puts "An error has occurred (#{e.class.name}):\n" + Rainbow(e.message).red
    end

    desc 'Check the status of a source directory that was previously loaded.'
    task status: :environment do
      source_directory_path = ENV['path']

      if source_directory_path.blank?
        puts Rainbow("Missing required argument: source_directory_path").red.bright
        next
      end
      next unless source_directory_path_is_valid?(source_directory_path)

      puts Rainbow("\nChecking on the status of SourceObjects with a path starting with: #{source_directory_path} ...").blue.bright
      puts "(this can be a slow process)\n\n"

      puts "-----------------------------"
      puts "|          Results          |"
      puts "-----------------------------"

      time = Benchmark.measure do
        number_of_local_files = (
          Dir.glob(File.join(source_directory_path, '**', '*'), File::FNM_DOTMATCH) - ['.', '..']
        ).select { |file| File.file?(file) }.count
        puts Rainbow("Number of files found in the source directory: #{number_of_local_files}").blue.bright
        puts "-> This number should match the next number, which will be the number of SourceObject in the ATC database.\n\n"

        source_object_count = SourceObject.where('path LIKE ?', "#{source_directory_path}%").count
        puts Rainbow("SourceObjects added to ATC database: #{source_object_count}").blue.bright
        puts "-> SourceObjects should equal the number of files in the source directory (#{Rainbow(number_of_local_files).blue.bright}).\n\n"

        if number_of_local_files != source_object_count
          puts Rainbow("ERROR: There was a mismatch between the number of files on the filesystem and the number of SourceObjects in the ATC database!").red.bright
          puts Rainbow("That's bad! This requires investigation!").red.bright
          next
        end

        fixity_checksum_count = SourceObject.where('path LIKE ? AND fixity_checksum_value IS NOT NULL', "#{source_directory_path}%").count
        puts Rainbow("SourceObjects with fixity checksums: #{fixity_checksum_count}").blue.bright
        puts "-> All SourceObjects should have fixity checksums (#{Rainbow(number_of_local_files).blue.bright}).\n\n"

        # # NOTE: The section below is currently commented out because it might not actually be helpful
        # # for determining the status of a source directory transfer.  PendingTransfer count rises and falls while
        # # a transfer occurs because PerformTransferJobs are always prioritized over PrepareTransferJobs.
        # #
        # # Check to see how many of the source directory files have PendingTransfer records
        # {
        #   'AWS' => 0, # storage_type 0 is AWS
        #   'GCP' => 1 # storage_type 1 is GCP
        # }.each do |storage_provider_type_name, storage_provider_type_value|
        #   count = PendingTransfer.where(
        #     'storage_provider_id IN (SELECT id FROM storage_providers WHERE storage_type = ?) '\
        #     'AND '\
        #     'source_object_id IN (SELECT id from source_objects WHERE path LIKE ?)',
        #     storage_provider_type_value,
        #     "#{source_directory_path}%"
        #   ).count
        #   puts Rainbow("#{storage_provider_type_name} PendingTransfers: #{count}").blue.bright
        # end
        # puts "-> PendingTransfers should equal 0 when all pre-transfer checksums have been calculated."
        # puts "NOTE: PendingTransfer numbers will rise and fall while the source directory transfer is in progress."
        # puts "Changes in these numbers are only an indication that the transfer is in progress. \n\n"

        # Check to see how many of the source directory files have StoredObject records
        aws_stored_object_count = StoredObject.where(
          'storage_provider_id IN (SELECT id FROM storage_providers WHERE storage_type = ?) '\
          'AND '\
          'source_object_id IN (SELECT id from source_objects WHERE path LIKE ?)',
          0,
          "#{source_directory_path}%"
        ).count
        puts Rainbow("AWS StoredObjects: #{aws_stored_object_count}").blue.bright

        gcp_stored_object_count = StoredObject.where(
          'storage_provider_id IN (SELECT id FROM storage_providers WHERE storage_type = ?) '\
          'AND '\
          'source_object_id IN (SELECT id from source_objects WHERE path LIKE ?)',
          1,
          "#{source_directory_path}%"
        ).count
        puts Rainbow("GCP StoredObjects: #{gcp_stored_object_count}").blue.bright

        puts "-> AWS and GCP StoredObject counts should equal the number of files in the source directory (#{Rainbow(number_of_local_files).blue.bright}) when all transfers have completed.\n\n"

        # Check to see how many of the source directory files have AWS FixityVerification records
        # NOTE: we only do fixity verifications on AWS records at this time.
        grouped_status_counts = FixityVerification.where(
          'source_object_id IN (SELECT id from source_objects WHERE path LIKE ?)',
          "#{source_directory_path}%"
        ).group(:status).count
        puts Rainbow('FixityVerifications:').blue.bright
        FixityVerification.statuses.keys.each do |status|
          puts Rainbow("#{status}: #{grouped_status_counts[status].to_i}").blue.bright
        end
        puts "-> FixityVerification success count should equal the number of files in the source directory (#{Rainbow(number_of_local_files).blue.bright}) when all transfers have completed fixity verification, and there should be 0 failures.\n\n"

        # Print summary (and any warnings)

        puts "-----------------------------"
        puts "|          Summary          |"
        puts "-----------------------------"

        puts "Local file count (#{Rainbow(number_of_local_files).blue.bright}) matches ATC DB SourceObject count (#{Rainbow(source_object_count).blue.bright})? #{number_of_local_files == source_object_count ? Rainbow("YES").green : Rainbow("NO").red.bright}"
        puts "Fixity checksums available for all SourceObjects? #{number_of_local_files == fixity_checksum_count ? Rainbow("YES").green : Rainbow("NO").red.bright}"
        puts "AWS transfers complete? #{number_of_local_files == aws_stored_object_count ? Rainbow("YES").green : Rainbow("NO").red.bright}"
        puts "GCP transfers complete? #{number_of_local_files == gcp_stored_object_count ? Rainbow("YES").green : Rainbow("NO").red.bright}"
        puts "Fixity verifications complete? #{number_of_local_files == grouped_status_counts['success'] ? Rainbow("YES").green : Rainbow("NO").red.bright}"
      end

      puts "\nStatus check finished in #{time.real.round(2)} seconds.\n\n"
    end
  end
end
