namespace :atc do
  namespace :aip do
    desc 'Load files from an AIP into ATC, load checksums from the AIP manifest, and initiate transfer and verification processes.'
    task load: :environment do
      aip_path = ENV['path']
      dry_run = ENV['dry_run'] == 'true'

      if aip_path.blank?
        puts "Missing required argument: aip_path"
        next
      end

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
    rescue Atc::Exceptions::AipLoadError => e
      puts "An error has occurred (#{e.class.name}):\n" + Rainbow(e.message).red
    end

    desc 'Check the status of an AIP that was previously loaded.'
    task status: :environment do
      aip_path = ENV['path']

      if aip_path.blank?
        puts "Missing required argument: aip_path"
        next
      end

      puts Rainbow("\nChecking on the status of SourceObjects with a path starting with: #{aip_path} ...").blue.bright
      puts "(this can be a slow process)\n\n"
      puts "------------------------------"

      time = Benchmark.measure do
        number_of_local_files = Dir.glob(File.join(aip_path, '**', '*')).select { |file| File.file?(file) }.count
        puts Rainbow("Number of files found in the AIP: #{number_of_local_files}").blue.bright
        puts "-> This number should match the next number, which will be the number of SourceObject in the ATC database.\n\n"

        source_object_count = SourceObject.where('path LIKE ?', "#{aip_path}%").count
        puts Rainbow("SourceObjects: #{source_object_count}").blue.bright
        puts "-> SourceObjects should equal the number of files in the AIP (#{Rainbow(number_of_local_files).blue.bright}).\n\n"

        if number_of_local_files != source_object_count
          puts Rainbow("ERROR: There was a mismatch between the number of files on the filesystem and the number of SourceObjects in the database!").red.bright
          puts Rainbow("That's bad!  This should be investigated further!\n").red.bright
        end

        # # NOTE: The section below is currently commented out because it might not actually be helpful
        # # for determining the status of an AIP transfer.  PendingTransfer count rises and falls while
        # # a transfer occurs because PerformTransferJobs are always prioritized over PrepareTransferJobs.
        # #
        # # Check to see how many of the AIP files have PendingTransfer records
        # {
        #   'AWS' => 0, # storage_type 0 is AWS
        #   'GCP' => 1 # storage_type 1 is GCP
        # }.each do |storage_provider_type_name, storage_provider_type_value|
        #   count = PendingTransfer.where(
        #     'storage_provider_id IN (SELECT id FROM storage_providers WHERE storage_type = ?) '\
        #     'AND '\
        #     'source_object_id IN (SELECT id from source_objects WHERE path LIKE ?)',
        #     storage_provider_type_value,
        #     "#{aip_path}%"
        #   ).count
        #   puts Rainbow("#{storage_provider_type_name} PendingTransfers: #{count}").blue.bright
        # end
        # puts "-> PendingTransfers should equal 0 when all pre-transfer checksums have been calculated."
        # puts "NOTE: PendingTransfer numbers will rise and fall while the AIP transfer is in progress."
        # puts "Changes in these numbers are only an indication that the transfer is in progress. \n\n"

        # Check to see how many of the AIP files have StoredObject records
        {
          'AWS' => 0, # storage_type 0 is AWS
          'GCP' => 1 # storage_type 1 is GCP
        }.each do |storage_provider_type_name, storage_provider_type_value|
          count = StoredObject.where(
            'storage_provider_id IN (SELECT id FROM storage_providers WHERE storage_type = ?) '\
            'AND '\
            'source_object_id IN (SELECT id from source_objects WHERE path LIKE ?)',
            storage_provider_type_value,
            "#{aip_path}%"
          ).count
          puts Rainbow("#{storage_provider_type_name} StoredObjects: #{count}").blue.bright
        end
        puts "-> AWS and GCP StoredObject counts should equal the number of files in the AIP (#{Rainbow(number_of_local_files).blue.bright}) when all transfers have completed.\n\n"

        # Check to see how many of the AIP files have AWS FixityVerification records
        # NOTE: we only do fixity verifications on AWS records at this time.
        grouped_counts = FixityVerification.where(
          'source_object_id IN (SELECT id from source_objects WHERE path LIKE ?)',
          "#{aip_path}%"
        ).group(:status).count
        puts Rainbow('FixityVerifications:').blue.bright
        FixityVerification.statuses.keys.each do |status|
          count = grouped_counts[status]
          puts Rainbow("#{status}: #{count.to_i}").blue.bright
        end
        puts "-> FixityVerification success count should equal the number of files in the AIP (#{Rainbow(number_of_local_files).blue.bright}) when all transfers have completed fixity verification, and there should be 0 failures.\n"
      end
      puts "------------------------------\n\n"
      puts "Status check finished in #{time.real.round(2)} seconds.\n\n"
    end
  end
end
