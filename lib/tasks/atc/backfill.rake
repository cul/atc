namespace :atc do
  namespace :backfill do
    desc 'Load files from an AIP into ATC, load checksums from the AIP manifest, and initiate transfer and verification processes.'
    task source_and_stored_objects: :environment do
      required_headers = [
        # SourceObject required headers
        'source_object_path',
        'object_size',
        'fixity_checksum_algorithm_name',
        'fixity_checksum_hex_value',
        # StoredObject required headers
        'transfer_checksum_algorithm_name',
        'transfer_checksum_hex_value',
        'aws_path',
        'aws_storage_provider_id', # Note: In production, preservation aws is 0
        'gcp_path',
        'gcp_storage_provider_id' # Note: In production, preservation gcp is 1
      ]

      csv_path = ENV['csv_path']
      dry_run = ENV['dry_run'] == 'true'

      if csv_path.blank?
        puts Rainbow("Missing required argument: csv_path").red.bright
        next
      end

      # Validate headers
      missing_headers = []
      CSV.foreach(csv_path) do |row|
        # Read first row only, validate headers, then break
        missing_headers = (required_headers - row)
        break
      end

      if missing_headers.present?
        puts "Missing required csv headers: #{missing_headers.join(', ')}"
        next
      end

      available_checksum_algorithms = ChecksumAlgorithm.all.map do |checksum_algorithm|
        [checksum_algorithm.name, checksum_algorithm]
      end.to_h

      storage_providers = StorageProvider.all.map do |storage_provider|
        [storage_provider.id, storage_provider]
      end.to_h

      CSV.foreach(csv_path, headers: true).with_index do |row, i|
        # Validate the data in this row
        # Ensure that none of the required values are blank:
        required_headers.each do |required_header|
          if row[required_header].nil? || row[required_header] == ''
            raise StandardError, "Error on CSV row #{i+1}.  Missing required value: #{required_header}"
          end
        end

        # Make sure that fixity_checksum_algorithm_name resolves to a ChecksumAlgorithm
        fixity_checksum_algorithm = available_checksum_algorithms[row['fixity_checksum_algorithm_name'].upcase]
        raise StandardError, "Could not resolve fixity_checksum_algorithm_name to a known ChecksumAlgorithm" if fixity_checksum_algorithm.nil?

        # Make sure that transfer_checksum_algorithm_name resolves to a ChecksumAlgorithm
        transfer_checksum_algorithm = available_checksum_algorithms[row['transfer_checksum_algorithm_name'].upcase]
        raise StandardError, "Could not resolve transfer_checksum_algorithm_name to a known ChecksumAlgorithm" if transfer_checksum_algorithm.nil?

        # Make sure that aws_storage_provider_id and gcp_storage_provider_id are numbers
        raise StandardError, "aws_storage_provider_id is not a number" unless row['aws_storage_provider_id'] =~ /\d+/
        raise StandardError, "gcp_storage_provider_id is not a number" unless row['gcp_storage_provider_id'] =~ /\d+/

        # Make sure that aws_storage_provider_id and gcp_storage_provider_id resolve to real StorageProvider objects
        aws_storage_provider = storage_providers[row['aws_storage_provider_id'].to_i]
        gcp_storage_provider = storage_providers[row['gcp_storage_provider_id'].to_i]
        raise StandardError, "Could not resolve aws_storage_provider_id to a known StorageProvider" if aws_storage_provider.nil?
        raise StandardError, "Could not resolve gcp_storage_provider_id to a known StorageProvider" if gcp_storage_provider.nil?

        if dry_run
          puts "Row #{i+1} appears to be valid.  No records were created because we are in dry_run mode."
          break
        end

        # Create source object
        source_object = SourceObject.create!(
          path: row['source_object_path'],
          object_size: row['object_size'].to_i,
          fixity_checksum_algorithm: fixity_checksum_algorithm,
          fixity_checksum_value: Atc::Utils::HexUtils.hex_to_bin(row['fixity_checksum_hex_value'])
        )

        # Create AWS StoredObject record
        aws_stored_object = StoredObject.create!(
          path: row['aws_path'],
          source_object: source_object,
          storage_provider: aws_storage_provider,
          transfer_checksum_algorithm: transfer_checksum_algorithm,
          transfer_checksum_value: Atc::Utils::HexUtils.hex_to_bin(row['transfer_checksum_hex_value']),
          transfer_checksum_part_size: nil, # We leave this blank because we're using a single part value
          transfer_checksum_part_count: nil, # We leave this blank because we're using a single part value
          is_backfilled_entry: true
        )

        # Create GCP StoredObject record
        gcp_stored_object = StoredObject.create!(
          path: row['gcp_path'],
          source_object: source_object,
          storage_provider: gcp_storage_provider,
          transfer_checksum_algorithm: transfer_checksum_algorithm,
          transfer_checksum_value: Atc::Utils::HexUtils.hex_to_bin(row['transfer_checksum_hex_value']),
          transfer_checksum_part_size: nil, # We leave this blank because we're using a single part value
          transfer_checksum_part_count: nil, # We leave this blank because we're using a single part value
          is_backfilled_entry: true
        )

        # Queue fixity verification job for the new AWS StoredObject
        # NOTE: We do not do this for the GCP StoredObject because we are not verifying GCP StoredObjects at this time.
        VerifyFixityJob.perform_later(aws_stored_object.id)
      end

      puts "\nDone!"
    end
  end
end
