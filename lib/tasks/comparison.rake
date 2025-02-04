# frozen_string_literal: true

namespace :atc do
  namespace :comparison do
    desc 'Used for checking if an old_path to new_path csv has any obvious mapping errors (like accidentally offset rows)'
    task verify_remediated_filenames: :environment do
      unless ENV['path_update_csv_file']
        puts 'Please supply a path_update_csv_file'
        next
      end

      # Verify that the CSV has old_path and new_path columns
      headers = CSV.open(ENV['path_update_csv_file'], 'r') { |csv| csv.first }
      unless ['old_path', 'new_path'] - headers == []
        puts "CSV must have old_path and new_path columns"
        next
      end

      CSV.foreach(ENV['path_update_csv_file'], headers: true).with_index.each do |row, i|
        old_path = row['old_path']
        new_path = row['new_path']

        # If a row has no old path, that means it's a new file and was not moved
        next if old_path.blank?

        old_filename = File.basename(old_path)
        expected_remediated_filename = Atc::Utils::ObjectKeyNameUtils.remediate_key_name(old_filename)
        # For now, based on Fred's old remediation script, also convert all mid-filename periods to underscores (but don't convert the last period)
        expected_remediated_filename = expected_remediated_filename.gsub(/\.(?=.*\..*)/, '_')
        # Also adding the rule below to match Fred's remediation script (but not replacing periods because we already handled those)
        expected_remediated_filename = expected_remediated_filename.gsub(/[^a-zA-Z0-9\.-]+/, '_')

        remediated_filename = File.basename(new_path)

        # Check if the new_filename matches the remediated version of the old filename
        if remediated_filename.strip != expected_remediated_filename.strip
          puts "Possible mismatch for old_path (on CSV row #{i+2}). Expected #{expected_remediated_filename}, but found: #{remediated_filename}"
        end

      end

      puts "Done!"
    end

    desc 'List multipart info for an S3 object (including part size)'
    # Example usage: bucket_name=cul-dlstor-digital-testing1 path='test-5gb-file-ubuntu.iso'
    task list_multipart_info: :environment do
      bucket_name = ENV['bucket_name']
      path = ENV['path']

      attributes = S3_CLIENT.get_object_attributes(
        bucket: bucket_name,
        key: path,
        object_attributes: %w[ETag Checksum ObjectParts StorageClass ObjectSize]
      )

      if attributes.object_parts.blank?
        puts "Single part file."
      else
        puts "Found multipart file (#{attributes.object_parts.total_parts_count} parts) "\
              "with individual part array data for #{attributes.object_parts.parts.length} parts."
      end
    end
  end
end
