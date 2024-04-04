# frozen_string_literal: true

def print_readability_check_progress(file_count, unreadable_directory_count, unreadable_file_count)
  print "\rReadability check progress: Found file count = #{file_count}, "\
        "Unreadable directory count = #{unreadable_directory_count}, "\
        "Unreadable file count = #{unreadable_file_count}"
end

def print_inventory_addition_progress(source_object_count)
  print "\rSourceObject records created: #{source_object_count}"
end

def validate_required_keys_and_print_error_messages(*keys)
  missing_keys = keys.select { |key| !ENV.key?(key) }
  return true if missing_keys.blank?

  puts Rainbow("Missing required arguments: #{missing_keys.join(', ')}").red
  false
end

namespace :atc do
  namespace :inventory do

    desc 'Updates the path of SourceObjects via old_path and new_path values in the given path_update_csv_file'
    task update_source_object_path: :environment do
      unless ENV['path_update_csv_file']
        puts 'Please supply a path_update_csv_file'
        next
      end

      CSV.foreach(ENV['path_update_csv_file'], headers: true).each do |row|
        old_path = row['old_path']
        new_path = row['new_path']

        source_object = SourceObject.for_path(old_path)
        print "Updating SourceObject #{source_object.id}..."
        raise "Could not find readable file at: #{new_path}" unless File.readable?(new_path)

        source_object.path = new_path
        source_object.assign_path_hash
        source_object.save(validate: false) # Validations normally prevent reassignment of path

        # Verify that object is findable via new_path
        raise "Cannot find updated SourceObject with new path" unless SourceObject.for_path(new_path)&.id == source_object.id
        puts "done!"
      end
    end

    desc 'Scan a directory and add all of its files to the source_objects table'
    task add_source_objects: :environment do
      path = ENV['path']
      dry_run = ENV['dry_run'] == 'true'
      skip_readability_check = ENV['skip_readability_check'] == 'true'

      if path.present?
        unless File.exist?(path)
          puts Rainbow("Could not find file at path: #{path}").red
          next
        end
      else
        puts Rainbow('Missing required argument: path').red
        next
      end

      puts "Running in dry run mode because dry_run=#{dry_run} !\n"

      puts "\nStep 1: Checking all files for readability..."
      if skip_readability_check
        puts "Skipping readability check because skip_readability_check=#{skip_readability_check}"
      else
        file_counter = 0
        unreadable_directory_path_error_list = []
        unreadable_file_path_list = []
        print_readability_check_progress(file_counter, 0, 0)
        Atc::Utils::FileUtils.stream_recursive_directory_read(path, unreadable_directory_path_error_list) do |file_path|
          file_counter += 1

          unreadable_file_path_list << file_path unless File.readable?(file_path)

          if file_counter % 1000 == 0
            print_readability_check_progress(file_counter, unreadable_directory_path_error_list.length, unreadable_file_path_list.length)
          end
        end
        print_readability_check_progress(file_counter, unreadable_directory_path_error_list.length, unreadable_file_path_list.length)
        puts "\n"

        if unreadable_directory_path_error_list.present? || unreadable_file_path_list.present?
          puts Rainbow("\nReadability check failed. Encountered the following errors:\n").red
          if unreadable_directory_path_error_list.present?
            puts Rainbow("- Found #{unreadable_directory_path_error_list.length} unreadable #{unreadable_directory_path_error_list.length == 1 ? 'directory' : 'directories'}:\n\t" + unreadable_directory_path_error_list.join("\n\t")).red
          end
          if unreadable_file_path_list.present?
            puts Rainbow("- Found #{unreadable_file_path_list.length} unreadable #{unreadable_file_path_list.length == 1 ? 'file' : 'files'}:\n\t" + unreadable_file_path_list.join("\n\t")).red
          end
          next
        end

        puts "Step 1: Done\n"
      end

      if dry_run
        puts Rainbow("\nExiting early because this script was run with dry_run=#{dry_run}").yellow
        next
      end

      puts "\nStep 2: Adding files to the inventory database..."

      source_object_counter = 0
      print_inventory_addition_progress(source_object_counter)
      Atc::Utils::FileUtils.stream_recursive_directory_read(path, false) do |file_path|
        size = File.size(file_path)
        source_object = SourceObject.create!(
          path: file_path,
          object_size: size,
        )
        source_object_counter += 1
        if source_object_counter % 1000 == 0
          print_inventory_addition_progress(source_object_counter)
        end
      end
      print_inventory_addition_progress(source_object_counter)
      puts "\nStep 2: Done!"

      puts "\nProcess complete!"
    end

    desc 'Create a checksum entry for a SourceObject at the given source_object_path.  '\
      'If sha256_checksum_hexdigest is given, uses the given value.  Otherwise reads the file '\
      'and generates a sha256 checksum.'
    task add_source_object_sha256_checksum: :environment do
      next unless validate_required_keys_and_print_error_messages('source_object_path')
      source_object_path = ENV['source_object_path']
      sha256_checksum_hexdigest = ENV['sha256_checksum_hexdigest']

      source_object = SourceObject.for_path(source_object_path)
      if source_object.nil?
        puts Rainbow("Could not find SourceObject record with path: #{source_object_path}").red
        next
      end

      if sha256_checksum_hexdigest.nil?
        # Generate checksum
        sha256_checksum_hexdigest = Digest::SHA256.file(source_object_path).hexdigest
      elsif !(sha256_checksum_hexdigest.match?(/^[A-Fa-f0-9]{64}$/))
        puts Rainbow("Not a valid sha256 checksum: #{sha256_checksum_hexdigest}").red
        next
      else
        # For consistency, convert user-supplied sha256 to lower case.
        # NOTE: This is fine for hex digests but would NOT be okay for a base64
        # digest, which is case-sensitive.
        sha256_checksum_hexdigest = sha256_checksum_hexdigest.downcase
      end

      puts "Found source_object with path: #{source_object_path}"
      puts "Adding sha256 checksum hexdigest: #{sha256_checksum_hexdigest}"

      checksum_algorithm = ChecksumAlgorithm.find_by(name: 'SHA256')
      Checksum.create!(
        checksum_algorithm: checksum_algorithm,
        source_object: source_object,
        value: sha256_checksum_hexdigest
      )
    end
  end
end
