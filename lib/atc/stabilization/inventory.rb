# frozen_string_literal: true

require 'csv'

class Atc::Stabilization::Inventory
  HEADERS = %w[file_path size skipped normalized_path virus_scan_result].freeze
  SKIPPED = 'SKIPPED'
  MAX_FILE_SIZE = 100.gigabytes

  Entry = Struct.new(:file_path, :size, :skipped, :normalized_path, :virus_scan_result, keyword_init: true) do
    def skipped?
      skipped == SKIPPED
    end

    def oversized?
      size > MAX_FILE_SIZE
    end

    def to_csv_row
      [file_path, size, skipped, normalized_path, virus_scan_result]
    end
  end

  attr_reader :csv_file

  def initialize(stabilization_dir:)
    @csv_file = File.join(stabilization_dir, 'normalization-log.csv')
  end

  # files is an array of [file_path, size] pairs returned by the source connector (what we get from Smb::Connector)
  def write_files(files)
    write_rows(files.map { |file_path, size| new_entry(file_path, size) })
  end

  def normalize_paths
    assigned_paths = Set.new
    all = entries

    all.each do |entry|
      next if entry.skipped?
      entry.normalized_path = normalized_path_for(entry.file_path, assigned_paths)
    end

    write_rows(all)
  end

  # results is a Hash of normalized_path => virus scan status
  def record_scan_results(results)
    all = entries
    all.each { |entry| entry.virus_scan_result = results[entry.normalized_path] }
    write_rows(all)
  end

  # Non-skipped files
  def each_transferable
    return to_enum(:each_transferable) unless block_given?

    each_row { |entry| yield entry unless entry.skipped? }
  end

  def oversized
    each_transferable.select(&:oversized?)
  end

  private

  def each_row
    return to_enum(:each_row) unless block_given?

    CSV.foreach(@csv_file, headers: true) do |row|
      yield Entry.new(
        file_path: row['file_path'], size: row['size'].to_i, skipped: row['skipped'],
        normalized_path: row['normalized_path'], virus_scan_result: row['virus_scan_result']
      )
    end
  end

  def entries
    each_row.to_a
  end

  def write_rows(rows)
    CSV.open(@csv_file, 'w') do |csv|
      csv << HEADERS
      rows.each { |entry| csv << entry.to_csv_row }
    end
  end

  def new_entry(file_path, size)
    Entry.new(file_path: file_path, size: size, skipped: skip?(file_path, size) ? SKIPPED : nil)
  end

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
