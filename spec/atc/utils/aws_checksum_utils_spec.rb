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

    # NOTE: We ran into this issue in the past, so that's why this test exists
    it 'properly handles parts that are made entirely of whitespace characters (0x0B line tab, 0x0C form feed, etc.)' do
      Tempfile.create('example-file-to-checksum') do |f|
        f.write('A' * multipart_threshold)
        f.write(Atc::Utils::HexUtils.hex_to_bin('0B') * (multipart_threshold - 10))
        f.write(Atc::Utils::HexUtils.hex_to_bin('0C') * 10)
        f.write('A' * multipart_threshold)
        expect(described_class.checksum_string_for_file(f.path, multipart_threshold)).to eq('OdsyWA==-3')
      end
    end
  end

  describe '.digest_file' do
    let(:crc32c_accumulator) { [] }
    let(:whole_object_digester) { Digest::CRC32c.new }
    let(:part_size) { 5.megabytes }

    # NOTE: We ran into this issue in the past, so that's why this test exists
    it 'properly handles parts that are made entirely of whitespace characters (0x0B line tab, 0x0C form feed, etc.)' do
      Tempfile.create('example-file-to-checksum') do |f|
        f.write('A' * part_size)
        f.write(Atc::Utils::HexUtils.hex_to_bin('0B') * (part_size - 10))
        f.write(Atc::Utils::HexUtils.hex_to_bin('0C') * 10)
        f.write('A' * part_size)
        described_class.digest_file(f.path, part_size, crc32c_accumulator, whole_object_digester)
      end
      expect(
        crc32c_accumulator.map { |checksum_bin_value| Base64.strict_encode64(checksum_bin_value) }
      ).to eq(['MDaLrw==', 'X/yhqA==', 'MDaLrw=='])
      expect(whole_object_digester.base64digest).to eq('NIRe3g==')
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
          binary_checksum_of_whole_file: nil,
          num_parts: 3,
          part_size: 5_242_880
        })
      end
    end

    it 'returns the expected hashes when calculating both multipart and whole object checksums' do
      Tempfile.create('example-file-to-checksum') do |f|
        f.write('A' * 15.megabytes)
        expected_whole_file_checksum = 'Nk5OvQ=='
        expect(described_class.multipart_checksum_for_file(f.path, calculate_whole_object: true)).to eq({
          binary_checksum_of_checksums: Base64.strict_decode64('EUOQdQ=='),
          binary_checksum_of_whole_file: Base64.strict_decode64(expected_whole_file_checksum),
          num_parts: 3, part_size: 5_242_880
        })
        # And make sure that our whole-file checksum matches the Digest::CRC32c whole file checksum
        expect(Digest::CRC32c.file(f.path).base64digest).to eq(expected_whole_file_checksum)
      end
    end
  end
end
