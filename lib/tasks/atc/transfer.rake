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
      extra_info = ENV['extra_info'] == 'true'

      if extra_info
        puts Rainbow("Running with extra_info=true option.  This will take longer.").blue.bright
      end

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

        if extra_info
          # If there's a mismatch between fixity_checksum_count and aws_stored_object_count, print info for how to fix this
          if fixity_checksum_count != aws_stored_object_count
            source_objects_witout_associated_aws_stored_objects = SourceObject.where(
              %Q(
                path LIKE ?
                AND
                id NOT IN
                (
                  SELECT source_object_id FROM stored_objects
                  WHERE
                  storage_provider_id IN (
                    SELECT id FROM storage_providers WHERE storage_type = ?
                  )
                )
              ),
              "#{source_directory_path}%",
              0
            ).pluck(:id)

            puts Rainbow(
                  "\nWarning: At least one SourceObject did not make it to AWS as a StoredObject.  "\
                  "To fix this, run each of these rake task commands:\n"
            ).orange.bright

            source_objects_witout_associated_aws_stored_objects.each do |source_object_id|
              puts "RAILS_ENV=#{ENV['RAILS_ENV'] || 'development'} bundle exec rake atc:queue:prepare_transfer source_object_id=#{source_object_id} enqueue_successor=true run_again=true"
            end
          end

          # If there's a mismatch between fixity_checksum_count and gcp_stored_object_count, print info for how to fix this
          if fixity_checksum_count != gcp_stored_object_count
            source_objects_witout_associated_gcp_stored_objects = SourceObject.where(
              %Q(
                path LIKE ?
                AND
                id NOT IN
                (
                  SELECT source_object_id FROM stored_objects
                  WHERE
                  storage_provider_id IN (
                    SELECT id FROM storage_providers WHERE storage_type = ?
                  )
                )
              ),
              "#{source_directory_path}%",
              1
            ).pluck(:id)

            puts Rainbow(
                  "\nWarning: At least one SourceObject did not make it to GCP as a StoredObject.  "\
                  "To fix this, run each of these rake task commands:\n"
            ).orange.bright

            source_objects_witout_associated_gcp_stored_objects.each do |source_object_id|
              puts "RAILS_ENV=#{ENV['RAILS_ENV'] || 'development'} bundle exec rake atc:queue:prepare_transfer source_object_id=#{source_object_id} enqueue_successor=true run_again=true"
            end
          end

          # If any fixity check failures were found, suggest that the user re-run a fixity check for them.
          if grouped_status_counts&.fetch('failure', 0) > 0
            stored_object_ids_for_failed_fixity_verifications = FixityVerification.where(
              'status = ? AND source_object_id IN (SELECT id from source_objects WHERE path LIKE ?)',
              FixityVerification.statuses[:failure],
              "#{source_directory_path}%"
            ).pluck(:stored_object_id)

            puts Rainbow(
                  "\nWarning: At least one fixity check was reported as a failure.  "\
                  'In most cases, this is caused by a network issue and is not actually a sign of a failed transfer.  '\
                  "To re-run these fixity checks, run each of these rake task commands:\n"
            ).orange.bright

            stored_object_ids_for_failed_fixity_verifications.each do |stored_object_id|
              puts "RAILS_ENV=#{ENV['RAILS_ENV'] || 'development'} bundle exec rake atc:queue:verify_fixity stored_object_id=#{stored_object_id}"
            end

            puts Rainbow(
                  "\nAfter the above commands have been run, each reported FixityVerification failure will change to a "\
                  'pending state instead, and the verification will re-run in the background.  Large files will '\
                  'take a while to re-verify, but you can run the status task to monitor progress.'
            ).orange.bright
          end
        end
      end

      puts "\nStatus check finished in #{time.real.round(2)} seconds.\n\n"
      puts "For more detailed info, add the extra_info=true parameter." unless extra_info
    end
  end
end
