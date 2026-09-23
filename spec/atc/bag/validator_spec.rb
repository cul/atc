# frozen_string_literal: true

require 'rails_helper'

describe Atc::Bag::Validator do
  let(:valid_bag_fixture) { Rails.root.join('spec/fixtures/files/stabilization_bags/valid_bag') }
  let(:bag_dir) { Dir.mktmpdir.tap { |dir| FileUtils.cp_r("#{valid_bag_fixture}/.", dir) } }
  let(:validator) { described_class.new(bag_dir) }

  after { FileUtils.remove_entry(bag_dir) if Dir.exist?(bag_dir) }

  describe '#initialize' do
    it 'can be instantiated' do
      expect(validator).to be_a(described_class)
    end

    it 'exposes the bag directory' do
      expect(validator.bag_dir).to eq(bag_dir)
    end
  end

  describe 'a valid bag' do
    it 'is valid' do
      expect(validator.valid?).to be(true)
    end

    it 'has no errors' do
      expect(validator.errors).to eq([])
    end
  end

  describe 'a bag directory that does not exist' do
    before { FileUtils.remove_entry(bag_dir) }

    it 'is not valid' do
      expect(validator.valid?).to be(false)
    end

    it 'reports that the directory does not exist' do
      expect(validator.errors).to eq(["#{bag_dir} does not exist"])
    end
  end

  describe 'a bag that is missing required tag files' do
    it 'reports a missing bagit.txt, which BagIt::Bag would otherwise silently write for us' do
      FileUtils.rm(File.join(bag_dir, 'bagit.txt'))
      expect(validator.errors).to eq(["#{bag_dir} is missing required tag file(s): bagit.txt"])
    end

    it 'reports a missing tagmanifest, which BagIt::Bag would otherwise skip checking' do
      FileUtils.rm(File.join(bag_dir, 'tagmanifest-sha256.txt'))
      expect(validator.errors).to eq(["#{bag_dir} is missing required tag file(s): tagmanifest-sha256.txt"])
    end

    it 'reports every missing tag file at once' do
      FileUtils.rm([File.join(bag_dir, 'bagit.txt'), File.join(bag_dir, 'tagmanifest-sha256.txt')])
      expect(validator.errors).to eq(
        ["#{bag_dir} is missing required tag file(s): bagit.txt, tagmanifest-sha256.txt"]
      )
    end
  end

  describe 'a bag whose contents do not match its manifests' do
    it 'is not valid when a payload file has been modified' do
      File.write(File.join(bag_dir, 'data', 'file.txt'), "modified\n")
      expect(validator.valid?).to be(false)
      expect(validator.errors.join).to include('data/file.txt')
    end

    it 'is not valid when a manifested payload file is missing' do
      FileUtils.rm(File.join(bag_dir, 'data', 'file.txt'))
      expect(validator.valid?).to be(false)
      expect(validator.errors.join).to include('data/file.txt')
    end

    it 'is not valid when a payload file is present but not in the manifest' do
      File.write(File.join(bag_dir, 'data', 'new-file.txt'), "surprise\n")
      expect(validator.valid?).to be(false)
      expect(validator.errors.join).to include('new-file.txt')
    end

    it 'is not valid when a tag file has been modified' do
      File.write(File.join(bag_dir, 'bag-info.txt'), "Payload-Oxum: 0.0\n")
      expect(validator.valid?).to be(false)
      expect(validator.errors.join).to include('bag-info.txt')
    end

    it 'is not valid when inventory.csv has been modified' do
      File.write(File.join(bag_dir, 'inventory.csv'), "file_path,size,skipped,normalized_path,virus_scan_result\n")
      expect(validator.valid?).to be(false)
      expect(validator.errors.join).to include('inventory.csv')
    end
  end

  describe '#errors' do
    it 'validates the bag once and returns the same result on subsequent calls' do
      expect(validator.errors).to be(validator.errors)
    end
  end
end
