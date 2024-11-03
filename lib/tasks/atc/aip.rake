namespace :atc do
  namespace :aip do
    desc 'Load files from an AIP into ATC, load checksums from the AIP manifest, and initiate transfer and verification processes.'
    task load: :environment do
      aip_path = ENV['path']
      dry_run = ENV['dry_run'] == 'true'

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
  end
end
