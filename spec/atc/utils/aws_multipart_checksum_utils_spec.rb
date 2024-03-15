# frozen_string_literal: true

require 'rails_helper'

describe Atc::Utils::AwsMultipartChecksumUtils do
  describe '.compute_default_part_size' do
    {
      5.megabytes => 5_242_880,
      500.megabytes => 5_242_880,
      5.gigabytes => 5_242_880,
      50.gigabytes => 5_368_710,
      100.gigabytes => 10_737_419
    }.each do |file_size, default_part_size|
      # it "For a file of size #{file_size}, returns a default part size of #{default_part_size}" do
      #   expect(described_class.compute_default_part_size(file_size)).to be(default_part_size)
      # end
    end

    it 'depends on the Aws::S3::MultipartFileUploader#compute_default_part_size method, and that method exists' do
      expect {
        Aws::S3::MultipartFileUploader.new.send(:compute_default_part_size, 100.megabytes)
      }.not_to raise_error
    end
  end

  describe '.checksum_for_file' do
    it 'returns the expected hash' do
      Tempfile.create('example-file-to-checksum') do |f|
        f.write('A' * 15.megabytes)
        expect(described_class.checksum_for_file(f.path)).to eq({
          base64_checksum: 'EUOQdQ==',
          num_parts: 3,
          part_size: 5_242_880
        })
      end
    end
  end
end
