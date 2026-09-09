# frozen_string_literal: true

require 'csv'

class Atc::Smb::CsvWriter
  HEADERS = %w[file_path size skipped normalized_path virus_scan_result].freeze

  attr_reader :csv_file

  def initialize(stabilization_dir: SMB_CONFIG[:stabilization_dir])
    @csv_file = File.join(stabilization_dir, 'normalization-log.csv')
  end

  # files is an Array of [file_path, size] pairs
  # Files that will not be transferred are marked as SKIPPED
  def write_files(files)
    CSV.open(@csv_file, 'w') do |csv|
      csv << HEADERS
      files.each { |file_path, size| csv << [file_path, size, skip?(file_path, size) ? 'SKIPPED' : nil] }
    end
  end

  def normalize_paths
    rows = CSV.read(@csv_file, headers: true)
    assigned_paths = Set.new

    CSV.open(@csv_file, 'w') do |csv|
      csv << HEADERS
      rows.each do |row|
        skipped = row['skipped']
        normalized_path = skipped ? nil : normalized_path_for(row['file_path'], assigned_paths)
        csv << [row['file_path'], row['size'], skipped, normalized_path]
      end
    end
  end

  # "results" is a hash of normalized_path => virus scan status
  def write_scan_results(results)
    rows = CSV.read(@csv_file, headers: true)

    CSV.open(@csv_file, 'w') do |csv|
      csv << HEADERS
      rows.each do |row|
        csv << [row['file_path'], row['size'], row['skipped'], row['normalized_path'],
                results[row['normalized_path']]]
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

  def normalized_path_for(file_path, assigned_paths)
    normalized_path = Atc::Utils::ObjectKeyNameUtils.remediate_key_name(
      file_path.delete_prefix('/'), assigned_paths
    )
    assigned_paths << normalized_path
    puts "Normalized path for #{file_path}: #{normalized_path}"
    normalized_path
  end

  def skip?(file_path, size)
    filename = File.basename(file_path)
    filename == 'Thumbs.db' || filename.start_with?('.') || size.zero?
  end
end
