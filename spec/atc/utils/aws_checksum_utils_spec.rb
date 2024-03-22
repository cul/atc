# frozen_string_literal: true

require 'rails_helper'

describe Atc::Utils::AwsChecksumUtils do
  describe '.checksum_string_for_file' do
    let(:multipart_threshold) { 5.megabytes }

    it 'returns a multipart checksum for a file with size equal to the multipart_threshold' do
      Tempfile.create('example-file-to-checksum') do |f|
        f.write('A' * multipart_threshold)
        expect(described_class.checksum_string_for_file(f.path, multipart_threshold)).to eq('mBmGog==-1')
      end
    end

    it 'returns a multipart checksum for a file with size greater than the multipart_threshold' do
      Tempfile.create('example-file-to-checksum') do |f|
        f.write('A' * (multipart_threshold + 1))
        expect(described_class.checksum_string_for_file(f.path, multipart_threshold)).to eq('3DhwZA==-2')
      end
    end

    it 'returns a whole file checksum for a file with size less than the multipart_threshold' do
      Tempfile.create('example-file-to-checksum') do |f|
        f.write('A' * (multipart_threshold - 1))
        expect(described_class.checksum_string_for_file(f.path, multipart_threshold)).to eq('g38HMg==')
      end
    end
  end

  describe '.compute_default_part_size' do
    {
      5.megabytes => 5_242_880,
      500.megabytes => 5_242_880,
      5.gigabytes => 5_242_880,
      50.gigabytes => 5_368_710,
      100.gigabytes => 10_737_419
    }.each do |file_size, default_part_size|
      it "For a file of size #{file_size}, returns a default part size of #{default_part_size}" do
        expect(described_class.compute_default_part_size(file_size)).to be(default_part_size)
      end
    end

    it 'depends on the Aws::S3::MultipartFileUploader#compute_default_part_size method, and that method exists' do
      expect {
        Aws::S3::MultipartFileUploader.new.send(:compute_default_part_size, 100.megabytes)
      }.not_to raise_error
    end
  end

  describe '.multipart_checksum_for_file' do
    it 'returns the expected hash' do
      Tempfile.create('example-file-to-checksum') do |f|
        f.write('A' * 15.megabytes)
        expect(described_class.multipart_checksum_for_file(f.path)).to eq({
          binary_checksum_of_checksums: Base64.strict_decode64('EUOQdQ=='),
          binary_checksum_of_object: nil,
          num_parts: 3,
          part_size: 5_242_880
        })
      end
    end

    it 'returns the expected hashes when calculating both sums' do
      Tempfile.create('example-file-to-checksum') do |f|
        f.write('A' * 15.megabytes)
        expect(described_class.multipart_checksum_for_file(f.path, calculate_whole_object: true)).to eq({
          binary_checksum_of_checksums: Base64.strict_decode64('EUOQdQ=='),
          binary_checksum_of_object: Base64.strict_decode64('Nk5OvQ=='),
          num_parts: 3,
          part_size: 5_242_880
        })
      end
    end
  end
end
