# frozen_string_literal: true

require 'rails_helper'

describe Atc::Aws::S3Downloader do
  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:bucket_name) { 'example_bucket' }
  let(:download_directory) { '/tmp/example-download-directory' }
  let(:s3_folder_prefix) { 'example/folder/prefix' }
  let(:download_directory_result) { { completed_downloads: 2, failed_downloads: 0 } }
  let(:transfer_manager) do
    instance_double(Aws::S3::TransferManager, download_directory: download_directory_result)
  end
  let(:s3_downloader) do
    allow(Aws::S3::TransferManager).to receive(:new).and_return(transfer_manager)
    described_class.new(bucket_name, download_directory, s3_client)
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(s3_downloader).to be_a(described_class)
    end
  end

  describe '#download_directory' do
    it 'downloads the given prefix to the local download directory' do
      expect(transfer_manager).to receive(:download_directory).with(
        download_directory, bucket: bucket_name, s3_prefix: s3_folder_prefix
      ).and_return(download_directory_result)
      s3_downloader.download_directory(s3_folder_prefix)
    end

    it 'returns the result of the download' do
      expect(s3_downloader.download_directory(s3_folder_prefix)).to eq(download_directory_result)
    end

    it 'raises an exception when the download fails' do
      allow(transfer_manager).to receive(:download_directory).and_raise(Aws::S3::Errors::NoSuchBucket.new(nil, nil))
      expect {
        s3_downloader.download_directory(s3_folder_prefix)
      }.to raise_error(Aws::S3::Errors::NoSuchBucket)
    end

    context 'when an object in the prefix does not exist' do
      let(:s3_client) do
        client = Aws::S3::Client.new(stub_responses: true)
        # Simulate a missing object in the S3 prefix
        client.stub_responses(:list_objects_v2, { contents: [{ key: "#{s3_folder_prefix}/a.txt", size: 3 }] })
        client.stub_responses(:head_object, 'NotFound')
        client
      end

      it 'raises a DirectoryDownloadError that includes the underlying per-object error' do
        Dir.mktmpdir do |dir|
          downloader = described_class.new(bucket_name, dir, s3_client)
          expect {
            downloader.download_directory(s3_folder_prefix)
          }.to raise_error(Aws::S3::DirectoryDownloadError) { |error|
            expect(error.errors.first).to be_a(Aws::S3::Errors::NotFound)
          }
        end
      end
    end
  end
end
