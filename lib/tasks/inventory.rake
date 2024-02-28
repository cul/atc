# frozen_string_literal: true

def print_readability_check_progress(file_count, unreadable_directory_count, unreadable_file_count)
  print "\rReadability check progress: Found file count = #{file_count}, "\
        "Unreadable directory count = #{unreadable_directory_count}, "\
        "Unreadable file count = #{unreadable_file_count}"
end

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
