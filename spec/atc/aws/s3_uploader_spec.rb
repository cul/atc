# frozen_string_literal: true

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

  describe '.initialize' do
    it 'can be instantiated' do
      expect(s3_uploader).to be_a(described_class)
    end
  end

  describe '.upload_file' do
    let(:multipart_threshold) { 5.megabytes }

    context 'single part upload' do
      before do
        allow(s3_object_file_upload_response).to receive(:checksum_crc32c).and_return('g38HMg==')
      end

      it 'successfully performs a single part upload when the file size is below the multipart_threshold' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A' * (multipart_threshold - 1))
          f.flush

          s3_uploader.upload_file(f.path, bucket_name, multipart_threshold: multipart_threshold)
        end
      end
    end

    context 'multipart upload' do
      before do
        allow(s3_object_file_upload_response).to receive(:checksum_crc32c).and_return('mBmGog==-1')
      end

      it 'successfully performs a multipart upload when the file is greater than or equal to the multipart_threshold' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A' * multipart_threshold)
          f.flush
          s3_uploader.upload_file(f.path, bucket_name, multipart_threshold: multipart_threshold)
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
          expect(Atc::Utils::AwsChecksumUtils).not_to receive(:checksum_string_for_file)
          s3_uploader.upload_file(f.path, bucket_name, precalculated_aws_crc32c: '4W3N7g==')
        end
      end

      it 'raises an exception when the AWS response crc32c does not match the provided crc32c' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A')
          f.flush
          expect {
            s3_uploader.upload_file(f.path, bucket_name, precalculated_aws_crc32c: 'bad+checksum')
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
          s3_uploader.upload_file(f.path, bucket_name)
        end
      end
    end

    context 'overwrite behavior when an object has already been uploaded with the same key' do
      before do
        allow(s3_object_file_upload_response).to receive(:checksum_crc32c).and_return('4W3N7g==')
      end

      let(:s3_object_exists) { true }

      it 'raises an exception if the `overwrite: true` option was not provided ' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A')
          f.flush
          expect(s3_object).not_to receive(:upload_file)
          expect {
            s3_uploader.upload_file(f.path, bucket_name)
          }.to raise_error(Atc::Exceptions::ObjectExists)
        end
      end

      it 'allows the upload to replace the existing object if `overwrite: true` was provided ' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A')
          f.flush
          expect(s3_object).to receive(:upload_file)
          expect {
            s3_uploader.upload_file(f.path, bucket_name, overwrite: true)
          }.not_to raise_error
        end
      end
    end
  end
end
