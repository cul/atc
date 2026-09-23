# frozen_string_literal: true

require 'rails_helper'

describe Atc::Bag::Layout do
  let(:bag_root_prefix) { 'repo_name_collection_name_YYYYMMDD_HHMMSS' }
  let(:layout) { described_class.new(bag_root_prefix) }

  describe '#initialize' do
    it 'can be instantiated' do
      expect(layout).to be_a(described_class)
    end

    it 'exposes the bag root prefix' do
      expect(layout.bag_root_prefix).to eq(bag_root_prefix)
    end
  end

  describe '#payload_path' do
    it 'places a file within the payload directory' do
      expect(layout.payload_path('file.txt')).to eq('data/file.txt')
    end

    it 'preserves subdirectories' do
      expect(layout.payload_path('subdir/nested/file.txt')).to eq('data/subdir/nested/file.txt')
    end

    it 'leaves out the bag root prefix so that the path is relative to the bag' do
      expect(layout.payload_path('file.txt')).not_to include(bag_root_prefix)
    end
  end

  describe '#payload_object_key' do
    it 'places a payload file under the bag root prefix' do
      expect(layout.payload_object_key('file.txt')).to eq("#{bag_root_prefix}/data/file.txt")
    end

    it 'preserves subdirectories' do
      expect(
        layout.payload_object_key('subdir/nested/file.txt')
      ).to eq("#{bag_root_prefix}/data/subdir/nested/file.txt")
    end
  end

  describe '#tag_file_object_key' do
    it 'places a tag file directly under the bag root prefix, outside of the payload directory' do
      expect(layout.tag_file_object_key('bag-info.txt')).to eq("#{bag_root_prefix}/bag-info.txt")
    end

    it 'uses only the file name when given a local file path' do
      expect(layout.tag_file_object_key('/tmp/work/bag-info.txt')).to eq("#{bag_root_prefix}/bag-info.txt")
    end
  end
end
