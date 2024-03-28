# frozen_string_literal: true

# rubocop:disable RSpec/StubbedMock

require 'rails_helper'

describe Atc::Aws::S3Uploader do
  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:bucket_name) { 'example_bucket' }
  let(:object_key) { 'key' }
  let(:s3_object_file_upload_response) { double(Seahorse::Client::Response) } # rubocop:disable RSpec/VerifiedDoubles
  let(:s3_object_exists) { false }
  let(:s3_object) do
    obj = Aws::S3::Object.new(
      bucket_name: 'bucket',
      key: object_key,
      client: s3_client
    )
    allow(obj).to receive(:exists?).and_return(s3_object_exists)
    allow(obj).to receive(:upload_file).and_yield(s3_object_file_upload_response)
    obj
  end
  let(:s3_uploader) do
    uploader = described_class.new(s3_client, bucket_name)
    allow(uploader).to receive(:generate_s3_object).and_return(s3_object)
    uploader
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(s3_uploader).to be_a(described_class)
    end
  end

  describe '#upload_file' do
    context 'whole file (single part) upload' do
      before do
        allow(s3_object_file_upload_response).to receive(:checksum_crc32c).and_return('BSABmg==')
      end

      it 'successfully performs a single part upload' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A' * 10.megabytes)
          f.flush
          expect(s3_uploader.upload_file(f.path, object_key, :whole_file)).to eq(true)
        end
      end
    end

    context 'multipart upload' do
      before do
        allow(s3_object_file_upload_response).to receive(:checksum_crc32c).and_return('UW/3VQ==-2')
      end

      it 'successfully performs a multipart upload' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A' * 10.megabytes)
          f.flush
          expect(s3_uploader.upload_file(f.path, object_key, :multipart)).to eq(true)
        end
      end
    end

    context 'auto-selection of single vs multipart' do
      it 'performs a multipart upload when the file is greater than or equal to the internal multipart threshold' do
        # multipart checksum format
        allow(s3_object_file_upload_response).to receive(:checksum_crc32c).and_return('RCWvCw==-10')
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A' * Atc::Constants::DEFAULT_MULTIPART_THRESHOLD)
          f.flush
          expect(s3_uploader.upload_file(f.path, object_key, :auto)).to eq(true)
        end
      end

      it 'performs a whole file (single part) upload when the file is below the internal multipart threshold' do
        # whole file checksum format
        allow(s3_object_file_upload_response).to receive(:checksum_crc32c).and_return('NL23Zw==')
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A' * (Atc::Constants::DEFAULT_MULTIPART_THRESHOLD - 1))
          f.flush
          expect(s3_uploader.upload_file(f.path, object_key, :auto)).to eq(true)
        end
      end
    end

    context 'checksum verification' do
      before do
        allow(s3_object_file_upload_response).to receive(:checksum_crc32c).and_return('4W3N7g==')
      end

      it 'uses a precalculated_aws_crc32c when given' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A')
          f.flush
          expect(s3_uploader).not_to receive(:calculate_aws_crc32c)
          s3_uploader.upload_file(f.path, object_key, :whole_file, precalculated_aws_crc32c: '4W3N7g==')
        end
      end

      it 'raises an exception when the AWS response crc32c does not match the provided crc32c' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A')
          f.flush
          expect {
            s3_uploader.upload_file(f.path, object_key, :whole_file, precalculated_aws_crc32c: 'bad+checksum')
          }.to raise_error(Atc::Exceptions::TransferError)
        end
      end

      it 'automatically generates a local crc32c when no precalculated_aws_crc32c option is given' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A')
          f.flush
          expect(
            Atc::Utils::AwsChecksumUtils
          ).to receive(:checksum_string_for_file).with(f.path, Integer).and_call_original
          s3_uploader.upload_file(f.path, object_key, :whole_file)
        end
      end
    end

    context 'overwrite behavior when an object has already been uploaded with the same key' do
      before do
        allow(s3_object_file_upload_response).to receive(:checksum_crc32c).and_return('4W3N7g==')
      end

      let(:s3_object_exists) { true }

      it 'raises an exception if the `overwrite: true` option was not provided' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A')
          f.flush
          expect(s3_object).not_to receive(:upload_file)
          expect {
            s3_uploader.upload_file(f.path, object_key, :whole_file)
          }.to raise_error(Atc::Exceptions::ObjectExists)
        end
      end

      it 'allows the upload to replace the existing object if `overwrite: true` was provided ' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A')
          f.flush
          expect(s3_object).to receive(:upload_file)
          expect {
            s3_uploader.upload_file(f.path, object_key, :whole_file, overwrite: true)
          }.not_to raise_error
        end
      end
    end

    context 'tags, metadata, and content type' do
      before do
        allow(s3_object_file_upload_response).to receive(:checksum_crc32c).and_return('BSABmg==')
      end

      it 'supports the addition of tags' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A' * 10.megabytes)
          f.flush
          expect(s3_object).to receive(:upload_file).with(
            String, hash_including(tagging: 'tag-key=tag-value')
          ).and_yield(s3_object_file_upload_response)
          expect(
            s3_uploader.upload_file(f.path, object_key, :whole_file, tags: { 'tag-key' => 'tag-value' })
          ).to eq(true)
        end
      end

      it 'supports the addition of metadata' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A' * 10.megabytes)
          f.flush
          expect(s3_object).to receive(:upload_file).with(
            String, hash_including(metadata: { 'metadata-key' => 'metadata-value' })
          ).and_yield(s3_object_file_upload_response)
          expect(
            s3_uploader.upload_file(f.path, object_key, :whole_file, metadata: { 'metadata-key' => 'metadata-value' })
          ).to eq(true)
        end
      end

      it 'sets the content type of the file, based on its extension' do
        Tempfile.create(['example-file-to-checksum', '.tiff']) do |f|
          f.write('A' * 10.megabytes)
          f.flush
          expect(s3_object).to receive(:upload_file).with(
            String, hash_including(content_type: 'image/tiff')
          ).and_yield(s3_object_file_upload_response)
          expect(
            s3_uploader.upload_file(f.path, bucket_name, :whole_file)
          ).to eq(true)
        end
      end
    end
  end

  describe '.tags_to_query_string' do
    it 'properly formats a single tag' do
      expect(
        described_class.tags_to_query_string({ 'key-1': 'value-1' })
      ).to eq(
        'key-1=value-1'
      )
    end

    it 'properly formats multiple tags' do
      expect(
        described_class.tags_to_query_string({ 'key-1': 'value-1', 'key-2': 'value-2' })
      ).to eq(
        'key-1=value-1&key-2=value-2'
      )
    end

    it 'url-encodes special characters in tags' do
      expect(
        described_class.tags_to_query_string({ 'animals': 'cats & dogs', 'kirby': '<(^_^)>' })
      ).to eq(
        'animals=cats%20&%20dogs&kirby=%3C(%5E_%5E)%3E'
      )
    end
  end
end

# rubocop:enable RSpec/StubbedMock
