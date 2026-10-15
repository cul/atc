# frozen_string_literal: true

require 'rails_helper'

describe Atc::Bag::PayloadManifest do
  let(:layout) { Atc::Bag::Layout.new('repo_name_collection_name_YYYYMMDD_HHMMSS') }
  let(:bag_dir) { Dir.mktmpdir }
  let(:payload_manifest) { described_class.new(bag_dir: bag_dir, layout: layout) }
  let(:manifest_file) { File.join(bag_dir, 'manifest-sha256.txt') }
  let(:checksum) { 'a' * 64 }

  after { FileUtils.remove_entry(bag_dir) }

  describe '#initialize' do
    it 'can be instantiated' do
      expect(payload_manifest).to be_a(described_class)
    end

    it 'writes the manifest to manifest-sha256.txt within the bag directory' do
      expect(payload_manifest.manifest_file).to eq(manifest_file)
    end

    it 'starts out with a file count and byte count of zero' do
      expect(payload_manifest.file_count).to eq(0)
      expect(payload_manifest.byte_count).to eq(0)
    end
  end

  describe '#start' do
    it 'removes a leftover manifest file, so a missing manifest means it was not finalized' do
      File.write(manifest_file, "leftover content\n")
      payload_manifest.start
      expect(File.exist?(manifest_file)).to be(false)
    end

    it 'discards rows added before it was called' do
      payload_manifest.start
      payload_manifest.add_row(checksum, 'file.txt', 100)
      payload_manifest.start
      payload_manifest.finalize([])
      expect(File.read(manifest_file)).to eq('')
    end

    it 'resets the file count and byte count' do
      payload_manifest.start
      payload_manifest.add_row(checksum, 'subdir/file.txt', 100)
      payload_manifest.start
      expect(payload_manifest.file_count).to eq(0)
      expect(payload_manifest.byte_count).to eq(0)
    end
  end

  describe '#add_row' do
    before { payload_manifest.start }

    it 'does not write the manifest file until it is finalized' do
      payload_manifest.add_row(checksum, 'file.txt', 100)
      expect(File.exist?(manifest_file)).to be(false)
    end

    it 'increments the file count and adds to the byte count' do
      payload_manifest.add_row(checksum, 'file-1.txt', 100)
      payload_manifest.add_row(checksum, 'file-2.txt', 200)
      expect(payload_manifest.file_count).to eq(2)
      expect(payload_manifest.byte_count).to eq(300)
    end

    it 'records every row with its own checksum and the correct totals when rows are added from multiple threads' do
      paths = Array.new(1000) { |number| "file-#{number}.txt" }
      threads = paths.each_slice(100).map do |slice|
        Thread.new { slice.each { |path| payload_manifest.add_row(Digest::SHA256.hexdigest(path), path, 1) } }
      end
      threads.each(&:join)

      payload_manifest.finalize(paths)
      expect(File.readlines(manifest_file, chomp: true)).to eq(
        paths.map { |path| "#{Digest::SHA256.hexdigest(path)}  data/#{path}" }
      )
      expect(payload_manifest.payload_oxum).to eq('1000.1000')
    end
  end

  describe '#finalize' do
    let(:checksum_1) { '1' * 64 }
    let(:checksum_2) { '2' * 64 }

    before { payload_manifest.start }

    it 'writes a checksum and payload path, separated by two spaces' do
      payload_manifest.add_row(checksum, 'subdir/file.txt', 100)
      payload_manifest.finalize(['subdir/file.txt'])
      expect(File.read(manifest_file)).to eq("#{checksum}  data/subdir/file.txt\n")
    end

    it 'writes rows in the order of the given paths, rather than the order they were added' do
      payload_manifest.add_row(checksum_2, 'file-2.txt', 200)
      payload_manifest.add_row(checksum_1, 'file-1.txt', 100)
      payload_manifest.finalize(['file-1.txt', 'file-2.txt'])
      expect(File.readlines(manifest_file)).to eq(
        ["#{checksum_1}  data/file-1.txt\n", "#{checksum_2}  data/file-2.txt\n"]
      )
    end

    it 'keeps paths that contain two spaces intact' do
      payload_manifest.add_row(checksum, 'file  with spaces.txt', 100)
      payload_manifest.finalize(['file  with spaces.txt'])
      expect(File.read(manifest_file)).to eq("#{checksum}  data/file  with spaces.txt\n")
    end

    context 'when a path has no recorded checksum' do
      before { payload_manifest.add_row(checksum_1, 'file-1.txt', 100) }

      it 'raises an error, without writing the manifest file' do
        expect { payload_manifest.finalize(['file-1.txt', 'file-2.txt']) }.to raise_error(
          Atc::Exceptions::PayloadManifestError, 'No checksum was recorded for file-2.txt'
        )
        expect(File.exist?(manifest_file)).to be(false)
      end
    end

    context 'when a checksum was recorded for a path that was not given' do
      before do
        payload_manifest.add_row(checksum_1, 'file-1.txt', 100)
        payload_manifest.add_row(checksum_2, 'file-2.txt', 200)
      end

      it 'raises an error, without writing the manifest file' do
        expect { payload_manifest.finalize(['file-1.txt']) }.to raise_error(
          Atc::Exceptions::PayloadManifestError,
          'Checksums were recorded for files missing from the inventory: file-2.txt'
        )
        expect(File.exist?(manifest_file)).to be(false)
      end
    end
  end

  describe '#payload_oxum' do
    it 'returns a byte count and file count of zero when no rows have been added' do
      expect(payload_manifest.payload_oxum).to eq('0.0')
    end

    it 'returns the total byte count and file count, separated by a period' do
      payload_manifest.start
      payload_manifest.add_row(checksum, 'file-1.txt', 100)
      payload_manifest.add_row(checksum, 'file-2.txt', 200)
      expect(payload_manifest.payload_oxum).to eq('300.2')
    end
  end
end
