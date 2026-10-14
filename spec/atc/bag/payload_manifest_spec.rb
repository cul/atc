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
    it 'creates an empty manifest file' do
      payload_manifest.start
      expect(File.read(manifest_file)).to eq('')
    end

    it 'makes sure the payload manifest file starts out empty' do
      File.write(manifest_file, "leftover content\n")
      payload_manifest.start
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

    it 'writes a checksum and payload path, separated by two spaces' do
      payload_manifest.add_row(checksum, 'subdir/file.txt', 100)
      expect(File.read(manifest_file)).to eq("#{checksum}  data/subdir/file.txt\n")
    end

    it 'records the payload path given by the layout, without the bag root prefix' do
      payload_manifest.add_row(checksum, 'file.txt', 100)
      expect(File.read(manifest_file)).to eq("#{checksum}  data/file.txt\n")
    end

    it 'appends rows in the order that they were added' do
      payload_manifest.add_row(checksum, 'file-1.txt', 100)
      payload_manifest.add_row(checksum, 'file-2.txt', 200)
      expect(File.readlines(manifest_file)).to eq(
        ["#{checksum}  data/file-1.txt\n", "#{checksum}  data/file-2.txt\n"]
      )
    end

    it 'increments the file count and adds to the byte count' do
      payload_manifest.add_row(checksum, 'file-1.txt', 100)
      payload_manifest.add_row(checksum, 'file-2.txt', 200)
      expect(payload_manifest.file_count).to eq(2)
      expect(payload_manifest.byte_count).to eq(300)
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
