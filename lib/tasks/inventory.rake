# frozen_string_literal: true

namespace :atc do
  namespace :inventory do
    desc 'Scan a directory and add all of its files to the '
    task add_transfer_sources: :environment do
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
        unreadable_file_counter = 0
        unreadable_directory_path_error_list = []
        print "\rReadability check progress: #{file_counter}"
        Atc::Utils::FileUtils.stream_recursive_directory_read(path, unreadable_directory_path_error_list) do |file_path|
          file_counter += 1

          unreadable_file_counter += 1 unless File.readable?(file_path)

          print "\rReadability check progress: #{file_counter}" if file_counter % 1000 == 0
        end
        print "\rReadability check progress: #{file_counter}"
        puts "\n"

        if unreadable_directory_path_error_list.present? || unreadable_file_counter > 0
          puts Rainbow("\nReadability check failed. Encountered the following errors:").red
          puts Rainbow("- Number of unreadable files:\n\t#{unreadable_file_counter}").red if unreadable_file_counter.present?
          if unreadable_directory_path_error_list.present?
            puts Rainbow("- The following directories were not readable (and any files inside them could not be read):\n\t" + unreadable_directory_path_error_list.join("\n\t")).red
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
      Atc::Utils::FileUtils.stream_recursive_directory_read(path, false) do |file_path|
        size = File.size(file_path)
        transfer_source = TransferSource.create!(
          path: file_path,
          object_size: size,
        )
      end
    end
  end
end
