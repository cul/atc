# frozen_string_literal: true

require 'csv'

class Atc::Smb::CsvWriter
  # TODO: We should place this file under a folder that indicates what share folder this csv was generated for
  def initialize
    @csv_file = "#{SMB_CONFIG[:stabilization_dir]}/normalization-log.csv"
  end

  # files is an Array of [file_path, size] pairs
  # Files that will not be transferred are marked as SKIPPED
  def write_files(files)
    CSV.open(@csv_file, 'w') do |csv|
      csv << ['file_path', 'size', 'skipped']
      files.each { |file_path, size| csv << [file_path, size, skip?(file_path, size) ? 'SKIPPED' : nil] }
    end
  end

  def normalize_paths
    rows = CSV.read(@csv_file, headers: true)

    CSV.open(@csv_file, 'w') do |csv|
      csv << ['file_path', 'size', 'skipped', 'normalized_path']
      rows.each do |row|
        skipped = row['skipped']
        normalized_path = skipped ? nil : normalized_path_for(row['file_path'])
        csv << [row['file_path'], row['size'], skipped, normalized_path]
      end
    end
  end

  def each_normalized_file
    return to_enum(:each_normalized_file) unless block_given?

    CSV.foreach(@csv_file, headers: true) do |row|
      next if row['skipped'] == 'SKIPPED'

      yield row['file_path'], row['normalized_path'], row['size'].to_i
    end
  end

  private

  def normalized_path_for(file_path)
    # ? Should we use this method?
    # ? Is it possible that the path will be normalized to the same value as another file?
    normalized_path = Atc::Utils::ObjectKeyNameUtils.remediate_key_name(file_path.delete_prefix('/'))
    puts "Normalized path for #{file_path}: #{normalized_path}"
    normalized_path
  end

  def skip?(file_path, size)
    filename = File.basename(file_path)
    filename == 'Thumbs.db' || filename.start_with?('.') || size.zero?
  end
end
