# frozen_string_literal: true

require 'rails_helper'

describe Atc::Gcp::StorageUploader do
  let(:storage_client) { Google::Cloud::Storage.new(credentials: GcpMockCredentials.new(GCP_CONFIG[:credentials])) }
  let(:bucket) { instance_double(Google::Cloud::Storage::Bucket) }
  let(:bucket_name) { 'example_bucket' }
  let(:object_key) { 'some-key' }
  let(:object_exists) { false }
  let(:storage_uploader) do
    uploader = described_class.new(storage_client, bucket_name)
    allow(uploader).to receive(:bucket).and_return(bucket)
    allow(uploader).to receive(:object_key_exists?).and_return(object_exists)
    uploader
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(storage_uploader).to be_a(described_class)
    end
  end

  describe '#upload_file' do
    context 'whole file (single part) upload' do
      it 'successfully performs a single part upload' do
        Tempfile.create(['example-file-to-checksum', '.tiff']) do |f|
          f.write('A' * 3)
          f.flush
          expect(bucket).to receive(:create_file).with(
            f.path,
            object_key,
            content_type: 'image/tiff',
            crc32c: 'XeVxEQ==',
            metadata: nil
          )
          expect(storage_uploader.upload_file(f.path, object_key)).to eq(true)
        end
      end
    end

    context 'checksum verification' do
      let(:file_content) { 'A' }
      let(:expected_crc32c_for_file_content) { Digest::CRC32c.base64digest(file_content) }

      before do
        allow(bucket).to receive(:create_file) do |_path, _bucket, kwargs|
          raise Google::Cloud::InvalidArgumentError unless kwargs[:crc32c] == expected_crc32c_for_file_content
        end
      end

      it 'uses a precalculated_whole_file_crc32c when given' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write(file_content)
          f.flush
          expect(storage_uploader).not_to receive(:calculate_crc32c)
          expect(
            storage_uploader.upload_file(
              f.path, object_key, precalculated_whole_file_crc32c: expected_crc32c_for_file_content
            )
          ).to eq(true)
        end
      end

      it 'raises an exception when the GCP API responds with a Google::Cloud::InvalidArgumentError, indicating that '\
        'the sent crc32c does not match the remote-side-calculated crc32c' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write(file_content)
          f.flush
          expect(storage_uploader).not_to receive(:calculate_crc32c)
          expect {
            storage_uploader.upload_file(f.path, object_key, precalculated_whole_file_crc32c: 'bad+checksum')
          }.to raise_error(Atc::Exceptions::TransferError)
        end
      end

      it 'automatically generates a local crc32c when no precalculated_aws_crc32c option is given' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write(file_content)
          f.flush
          expect(storage_uploader).to receive(:calculate_crc32c).and_call_original
          expect(storage_uploader.upload_file(f.path, object_key)).to eq(true)
        end
      end
    end

    context 'overwrite behavior when an object has already been uploaded with the same key' do
      let(:object_exists) { true }

      it 'raises an exception if the `overwrite: true` option was not provided' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A')
          f.flush
          expect(bucket).not_to receive(:create_file)
          expect {
            storage_uploader.upload_file(f.path, object_key)
          }.to raise_error(Atc::Exceptions::ObjectExists)
        end
      end

      it 'allows the upload to replace the existing object if `overwrite: true` was provided ' do
        Tempfile.create('example-file-to-checksum') do |f|
          f.write('A')
          f.flush
          expect(bucket).to receive(:create_file)
          expect {
            storage_uploader.upload_file(f.path, object_key, overwrite: true)
          }.not_to raise_error
        end
      end
    end

    context 'metadata' do
      it 'supports the addition of metadata' do
        Tempfile.create(['example-file-to-checksum', '.tiff']) do |f|
          f.write('A')
          f.flush
          expect(bucket).to receive(:create_file).with(
            f.path, object_key,
            content_type: 'image/tiff', crc32c: '4W3N7g==', metadata: { 'metadata-key' => 'metadata-value' }
          )
          expect(
            storage_uploader.upload_file(f.path, object_key, metadata: { 'metadata-key' => 'metadata-value' })
          ).to eq(true)
        end
      end
    end
  end
end
