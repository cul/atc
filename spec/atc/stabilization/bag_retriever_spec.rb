# frozen_string_literal: true

require 'rails_helper'

describe Atc::Stabilization::BagRetriever do
  let(:bucket) { 'example_bucket' }
  let(:bag_root_prefix) { 'repo_name_collection_name_20260923_120000' }
  let(:download_dir) { Dir.mktmpdir }
  let(:bag_path) { File.join(download_dir, bag_root_prefix) }
  let(:valid_bag_fixture) { Rails.root.join('spec/fixtures/files/stabilization_bags/valid_bag') }
  let(:s3_downloader) { instance_double(Atc::Aws::S3Downloader) }
  let(:bag_retriever) do
    described_class.new(bucket: bucket, bag_root_prefix: bag_root_prefix, download_dir: download_dir)
  end

  before do
    allow(Atc::Aws::S3Downloader).to receive(:new).and_return(s3_downloader)
    allow(StabilizationMailer).to receive(:notify)
  end

  after { FileUtils.remove_entry(download_dir) }

  def stub_download_of_bag
    allow(s3_downloader).to receive(:download_directory) do
      FileUtils.cp_r(valid_bag_fixture, bag_path)
      # Optionally modify the downloaded bag to force errors
      yield if block_given?
      { completed_downloads: 6, failed_downloads: 0 }
    end
  end

  describe '#retrieve' do
    context 'when a valid bag is downloaded' do
      before { stub_download_of_bag }

      it 'returns true' do
        expect(bag_retriever.retrieve).to be(true)
      end

      it 'downloads the bag prefix from the given bucket to the download directory' do
        bag_retriever.retrieve
        expect(Atc::Aws::S3Downloader).to have_received(:new).with(bucket, download_dir)
        expect(s3_downloader).to have_received(:download_directory).with(bag_root_prefix)
      end

      it 'sends a success notification' do
        bag_retriever.retrieve
        expect(StabilizationMailer).to have_received(:notify).with(
          'Successfully downloaded bag', /successfully downloaded to #{bag_path}/
        )
      end
    end

    context 'when the bag has already been downloaded' do
      before do
        FileUtils.mkdir_p(bag_path)
        allow(s3_downloader).to receive(:download_directory)
      end

      it 'returns false' do
        expect(bag_retriever.retrieve).to be(false)
      end

      it 'does not download the bag again' do
        bag_retriever.retrieve
        expect(s3_downloader).not_to have_received(:download_directory)
      end

      it 'sends a notification saying that the directory already exists' do
        bag_retriever.retrieve
        expect(StabilizationMailer).to have_received(:notify).with(
          "Couldn't download bag", "The directory #{bag_path} already exists."
        )
      end
    end

    context 'when the bag prefix has no files in it' do
      before do
        allow(s3_downloader).to receive(:download_directory).and_return(
          { completed_downloads: 0, failed_downloads: 0 }
        )
      end

      it 'returns false' do
        expect(bag_retriever.retrieve).to be(false)
      end

      it 'sends a notification naming the S3 location for investigation purposes' do
        bag_retriever.retrieve
        expect(StabilizationMailer).to have_received(:notify).with(
          "Couldn't download bag", "No files were found at s3://#{bucket}/#{bag_root_prefix}."
        )
      end
    end

    context 'when the download fails partway through' do
      before do
        allow(s3_downloader).to receive(:download_directory).and_raise(
          Aws::S3::DirectoryDownloadError.new('object is missing')
        )
      end

      it 'returns false' do
        expect(bag_retriever.retrieve).to be(false)
      end

      it 'sends a notification telling the recipient to remove the incomplete download' do
        bag_retriever.retrieve
        expect(StabilizationMailer).to have_received(:notify).with(
          "Couldn't download bag", /object is missing.*Remove the incomplete download at #{bag_path}/m
        )
      end
    end

    context 'when the downloaded bag is not valid' do
      before { stub_download_of_bag { FileUtils.rm(File.join(bag_path, 'tagmanifest-sha256.txt')) } }

      it 'returns false' do
        expect(bag_retriever.retrieve).to be(false)
      end

      it 'sends a notification that includes the validation errors' do
        bag_retriever.retrieve
        expect(StabilizationMailer).to have_received(:notify).with(
          'Failed to download bag', /is not valid:.*tagmanifest-sha256.txt/m
        )
      end
    end
  end
end
