# frozen_string_literal: true

require 'rails_helper'

describe Atc::Stabilization::Inventory do
  let(:run_dir) { Dir.mktmpdir }
  let(:inventory) { described_class.new(run_dir: run_dir) }

  after { FileUtils.remove_entry(run_dir) }

  # Reads inventory.csv back as an array of hashes (keyed by column name)
  def csv_rows
    CSV.read(inventory.csv_file, headers: true).map(&:to_h)
  end

  def csv_row_for(file_path)
    csv_rows.find { |row| row['file_path'] == file_path }
  end

  describe '#initialize' do
    it 'writes the inventory to inventory.csv within the run directory' do
      expect(inventory.csv_file).to eq(File.join(run_dir, 'inventory.csv'))
    end
  end

  describe '#write_files' do
    before do
      inventory.write_files(
        [
          ['/dir/file.txt', 100],
          ['/dir/Thumbs.db', 50],
          ['/dir/.hidden-file', 20],
          ['/dir/empty-file.txt', 0]
        ]
      )
    end

    it 'writes a header row' do
      expect(CSV.read(inventory.csv_file, headers: true).headers).to eq(described_class::HEADERS)
    end

    it 'writes a row for each file, recording its path and size' do
      expect(csv_rows.map { |row| [row['file_path'], row['size']] }).to eq(
        [['/dir/file.txt', '100'], ['/dir/Thumbs.db', '50'], ['/dir/.hidden-file', '20'],
         ['/dir/empty-file.txt', '0']]
      )
    end

    it 'does not skip a regular file' do
      expect(csv_row_for('/dir/file.txt')['skipped']).to eq('false')
    end

    it 'skips Thumbs.db, files that starts with a period and 0 byte files' do
      expect(csv_row_for('/dir/Thumbs.db')['skipped']).to eq('true')
      expect(csv_row_for('/dir/.hidden-file')['skipped']).to eq('true')
      expect(csv_row_for('/dir/empty-file.txt')['skipped']).to eq('true')
    end

    it 'leaves the normalized path and virus scan result blank, because they are filled in later' do
      expect(csv_row_for('/dir/file.txt')).to include('normalized_path' => nil, 'virus_scan_result' => nil)
    end
  end

  describe '#normalize_paths' do
    before do
      inventory.write_files(
        [
          ['/dir/file.txt', 100],
          ['/dir/my file.txt', 100],
          ['/dir/my file.txt', 100],
          ['/dir/Thumbs.db', 50]
        ]
      )
      inventory.normalize_paths
    end

    it 'removes the leading slash from the source file path' do
      expect(csv_row_for('/dir/file.txt')['normalized_path']).to eq('dir/file.txt')
    end

    it 'replaces characters that are not allowed in an object key' do
      expect(csv_rows[1]['normalized_path']).to eq('dir/my_file.txt')
    end

    it 'gives a distinct normalized path to files that would otherwise collide' do
      expect(csv_rows[2]['normalized_path']).to eq('dir/my_file_1.txt')
    end

    it 'leaves skipped files without a normalized path' do
      expect(csv_row_for('/dir/Thumbs.db')['normalized_path']).to be_nil
    end
  end

  describe '#record_scan_results' do
    before do
      inventory.write_files([['/dir/file.txt', 100], ['/dir/other.txt', 100], ['/dir/Thumbs.db', 50]])
      inventory.normalize_paths
      inventory.record_scan_results('dir/file.txt' => 'NO_THREATS_FOUND', 'dir/other.txt' => 'THREATS_FOUND')
    end

    it 'records the scan result for each normalized path' do
      expect(csv_rows.map { |row| [row['normalized_path'], row['virus_scan_result']] }).to include(
        ['dir/file.txt', 'NO_THREATS_FOUND'], ['dir/other.txt', 'THREATS_FOUND']
      )
    end

    it 'leaves skipped files without a scan result' do
      expect(csv_row_for('/dir/Thumbs.db')['virus_scan_result']).to be_nil
    end
  end

  describe '#each_transferable' do
    before { inventory.write_files([['/dir/file.txt', 100], ['/dir/Thumbs.db', 50]]) }

    it 'yields the files that are not skipped' do
      expect { |block| inventory.each_transferable(&block) }.to yield_successive_args(
        an_object_having_attributes(file_path: '/dir/file.txt', size: 100)
      )
    end

    it 'returns an enumerator when no block is given' do
      expect(inventory.each_transferable.map(&:file_path)).to eq(['/dir/file.txt'])
    end
  end

  describe '#oversized' do
    before do
      inventory.write_files(
        [
          ['/dir/small-file.txt', 100],
          ['/dir/large-file.txt', described_class::MAX_FILE_SIZE + 1]
        ]
      )
    end

    it 'returns only the files that are larger than the maximum file size' do
      expect(inventory.oversized.map(&:file_path)).to eq(['/dir/large-file.txt'])
    end

    it 'returns nothing when every file is within the maximum file size' do
      inventory.write_files([['/dir/small-file.txt', 100]])
      expect(inventory.oversized).to eq([])
    end
  end
end
