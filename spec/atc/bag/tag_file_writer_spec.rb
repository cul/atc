# frozen_string_literal: true

require 'rails_helper'

describe Atc::Bag::TagFileWriter do
  let(:bag_dir) { Dir.mktmpdir }
  let(:manifest_file) { File.join(bag_dir, 'manifest-sha256.txt') }
  let(:inventory_file) { File.join(bag_dir, 'inventory.csv') }
  let(:bagit_file) { File.join(bag_dir, 'bagit.txt') }
  let(:bag_info_file) { File.join(bag_dir, 'bag-info.txt') }
  let(:tag_manifest_file) { File.join(bag_dir, 'tagmanifest-sha256.txt') }
  let(:virus_check_passed) { true }
  let(:tag_file_writer) do
    described_class.new(
      source_dir: '/source/repo_name/collection_name',
      payload_oxum: '33.1',
      manifest_file: manifest_file,
      inventory_file: inventory_file,
      virus_check_passed: virus_check_passed,
      bag_dir: bag_dir,
      repository_name: 'repo_name',
      collection_name: 'collection_name'
    )
  end

  # The payload manifest and inventory are written by other parts of the stabilization script
  # so they have to already exist
  before do
    FileUtils.mkdir_p(File.join(bag_dir, 'data'))
    File.write(File.join(bag_dir, 'data', 'file.txt'), "This is an example payload file.\n")
    checksum = Digest::SHA256.file(File.join(bag_dir, 'data', 'file.txt')).hexdigest
    File.write(manifest_file, "#{checksum}  data/file.txt\n")
    File.write(
      inventory_file,
      "file_path,size,skipped,normalized_path,virus_scan_result\n" \
      "/file.txt,33,false,file.txt,NO_THREATS_FOUND\n"
    )
  end

  after { FileUtils.remove_entry(bag_dir) }

  # Reads bag-info.txt as a hash for easier testing
  def bag_info
    File.readlines(bag_info_file).to_h { |line| line.chomp.split(': ', 2) }
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(tag_file_writer).to be_a(described_class)
    end
  end

  describe '#write_tag_files' do
    before { tag_file_writer.write_tag_files }

    it 'writes bagit.txt' do
      expect(File.read(bagit_file)).to eq("BagIt-Version: 1.0\nTag-File-Character-Encoding: UTF-8\n")
    end

    describe 'bag-info.txt' do
      it 'records the payload oxum, repository name and collection name' do
        expect(bag_info).to include(
          'Payload-Oxum' => '33.1',
          'Repository-Name' => 'repo_name',
          'Collection-Name' => 'collection_name'
        )
      end

      it 'records where the content came from' do
        expect(bag_info).to include(
          'Content-Source-Type' => described_class::CONTENT_SOURCE_TYPE,
          'Content-Source-Path' => '/source/repo_name/collection_name'
        )
      end

      it 'records the date that the bag was created' do
        expect(bag_info['Bagging-Date']).to eq(Time.zone.today.strftime('%Y-%m-%d'))
      end

      it 'records a passing virus check' do
        expect(bag_info['Virus-Check-Result']).to eq('PASS')
      end

      context 'when the virus check did not pass' do
        let(:virus_check_passed) { false }

        it 'records a failing virus check, pointing to the inventory for details' do
          expect(bag_info['Virus-Check-Result']).to eq('FAIL - See inventory.csv for additional details.')
        end
      end
    end

    describe 'tagmanifest-sha256.txt' do
      it 'lists every tag file that gets checksummed' do
        expect(File.readlines(tag_manifest_file).map { |line| line.split.last }).to eq(
          ['bagit.txt', 'bag-info.txt', 'manifest-sha256.txt', 'inventory.csv']
        )
      end

      it 'records the sha256 checksum of each tag file' do
        expect(File.read(tag_manifest_file)).to include(
          "#{Digest::SHA256.file(inventory_file).hexdigest}  inventory.csv"
        )
      end

      it 'does not list itself' do
        expect(File.read(tag_manifest_file)).not_to include('tagmanifest-sha256.txt')
      end
    end

    it 'produces a bag that passes validation' do
      expect(Atc::Bag::Validator.new(bag_dir).errors).to eq([])
    end
  end

  describe '#tag_files' do
    it 'returns every tag file, including the tag manifest' do
      expect(tag_file_writer.tag_files).to eq(
        [bagit_file, bag_info_file, manifest_file, inventory_file, tag_manifest_file]
      )
    end
  end
end
