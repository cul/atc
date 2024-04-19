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
        expected_remediated_filename = expected_remediated_filename.gsub(/[^a-zA-Z0-9\.]+/, '_')

        remediated_filename = File.basename(new_path)

        # Check if the new_filename matches the remediated version of the old filename
        if remediated_filename != expected_remediated_filename
          puts "Possible mismatch for old_path (on CSV row #{i+2}). Expected #{expected_remediated_filename}, but found: #{remediated_filename}"
        end

      end

      puts "Done!"
    end
  end
end
