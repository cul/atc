# frozen_string_literal: true

require 'rails_helper'

describe Atc::Stabilization::Processor do
  let(:bag_name) { 'Starr_Wango_Weng_Interview_20260920_120000' }
  let(:source_path) { '/existing-dir/subdir' }
  let(:source_files) { [['/existing-dir/subdir/file.txt', 32]] }
  let(:payload_object_key) { "#{bag_name}/data/existing-dir/subdir/file.txt" }
  let(:scan_status) { 'NO_THREATS_FOUND' }
  let(:stabilization_bucket) { STABILIZATION_CONFIG[:stabilization_bucket] }

  let(:connector) { instance_double(Atc::Smb::Connector, smb_address: 'smb://example.com/Groups') }
  let(:uploader) { instance_double(Atc::Stabilization::BagUploader, upload_file: true, directory_exists: false) }
  let(:virus_scan_checker) { instance_double(Atc::Aws::VirusScanChecker) }

  let(:processor) do
    described_class.new(
      source_path: source_path, source_type: 'ldrive', repository_name: 'Starr',
      collection_name: 'Wango Weng Interview', bag_name: bag_name
    )
  end

  before do
    allow(Atc::Smb::Connector).to receive(:new).and_return(connector)
    allow(Atc::Stabilization::BagUploader).to receive(:new).and_return(uploader)
    allow(Atc::Aws::VirusScanChecker).to receive(:new).and_return(virus_scan_checker)
    allow(StabilizationMailer).to receive(:notify)
    allow(connector).to receive(:list_files).and_return(source_files)

    allow(connector).to receive(:download_file) do |_remote_dir, _file_path, local_path, **|
      File.write(local_path, 'This is an example payload file.')
      local_path
    end

    allow(virus_scan_checker).to receive(:each_scan_result) do |object_keys, &block|
      object_keys.each { |object_key| block.call(object_key, scan_status) }
    end
  end

  after { FileUtils.rm_rf(processor.run_dir) }

  describe '#s3_uri' do
    it 'returns the expected location within the stabilization bucket' do
      expect(processor.s3_uri).to eq("s3://#{stabilization_bucket}/#{bag_name}")
    end
  end

  describe '#run' do
    context 'when every file transfers and passes the virus scan' do
      it 'reports success, along with the location of the bag' do
        expect(processor.run).to eq([true, "s3://#{stabilization_bucket}/#{bag_name}"])
      end

      it 'uploads each payload file under the data directory of the bag' do
        processor.run
        expect(uploader).to have_received(:upload_file).with(String, payload_object_key)
      end

      it 'uploads the tag files to the top level of the bag' do
        processor.run
        ['bagit.txt', 'bag-info.txt', 'manifest-sha256.txt', 'inventory.csv', 'tagmanifest-sha256.txt'].each do |file|
          expect(uploader).to have_received(:upload_file).with(String, "#{bag_name}/#{file}")
        end
      end

      it 'removes the downloaded file once it has been uploaded' do
        processor.run
        expect(Dir.glob(File.join(processor.run_dir, '*.txt'))).to eq([])
      end

      it 'removes the local run directory' do
        run_dir = processor.run_dir
        processor.run
        expect(Dir.exist?(run_dir)).to be(false)
      end
    end

    context 'when the bag has already been uploaded' do
      before { allow(uploader).to receive(:directory_exists).and_return(true) }

      it 'raises an error rather than overwriting it' do
        expect { processor.run }.to raise_error(
          Atc::Exceptions::DuplicateDirectory, /Path already exists: #{bag_name}/
        )
      end
    end

    context 'when a source file is too large' do
      let(:source_files) { [['/existing-dir/subdir/large-file.txt', 101.gigabytes]] }

      it 'reports failure, without a bag location' do
        expect(processor.run).to eq([false, nil])
      end

      it 'sends a notification naming the oversized file' do
        processor.run
        expect(StabilizationMailer).to have_received(:notify).with(
          'Large files detected', '/existing-dir/subdir/large-file.txt'
        )
      end

      it 'does not upload anything' do
        processor.run
        expect(uploader).not_to have_received(:upload_file)
      end
    end

    context 'when a file does not pass the virus scan' do
      let(:scan_status) { 'THREATS_FOUND' }

      it 'reports failure, along with the location of the bag' do
        expect(processor.run).to eq([false, "s3://#{stabilization_bucket}/#{bag_name}"])
      end

      it 'still finalizes the bag, so that the failure can be investigated' do
        processor.run
        expect(uploader).to have_received(:upload_file).with(String, "#{bag_name}/tagmanifest-sha256.txt")
      end

      it 'leaves the local run directory in place' do
        processor.run
        expect(Dir.exist?(processor.run_dir)).to be(true)
      end
    end

    context 'when a file times out waiting for a scan result' do
      let(:scan_status) { Atc::Aws::VirusScanChecker::TIMED_OUT }

      it 'reports failure, because a timed out file is treated as a failure' do
        expect(processor.run).to eq([false, "s3://#{stabilization_bucket}/#{bag_name}"])
      end
    end

    context 'when the bag cannot be finalized' do
      before do
        allow(Atc::Bag::TagFileWriter).to receive(:new).and_raise(StandardError, 'could not write tag files')
      end

      it 'reports failure, along with the location of the bag' do
        expect(processor.run).to eq([false, "s3://#{stabilization_bucket}/#{bag_name}"])
      end

      it 'leaves the local run directory in place' do
        processor.run
        expect(Dir.exist?(processor.run_dir)).to be(true)
      end
    end
  end

  describe '#download_and_process_source_files' do
    let(:file_paths) { Array.new(10) { |number| "/dir/file-#{number + 1}.txt" } }
    let(:source_files) { file_paths.map { |file_path| [file_path, 12] } }
    let(:manifest_file) { File.join(processor.run_dir, 'manifest-sha256.txt') }
    let(:staging_paths) { Queue.new }

    before do
      allow(connector).to receive(:download_file) do |_remote_dir, file_path, local_path, **|
        staging_paths << local_path
        # The first file finishes last, so the order files finish in differs from the inventory
        sleep(0.1) if file_path == '/dir/file-1.txt'
        File.write(local_path, file_path)
        local_path
      end

      processor.add_source_files_to_csv
      processor.normalize_source_paths
    end

    it 'uploads every file' do
      processor.download_and_process_source_files
      file_paths.each do |file_path|
        expect(uploader).to have_received(:upload_file).with(String, "#{bag_name}/data#{file_path}")
      end
    end

    it 'writes the manifest in the order of the inventory, with each file paired with its own checksum' do
      processor.download_and_process_source_files
      expect(File.readlines(manifest_file, chomp: true)).to eq(
        file_paths.map { |file_path| "#{Digest::SHA256.hexdigest(file_path)}  data#{file_path}" }
      )
    end

    it 'downloads each file to its own staging path' do
      processor.download_and_process_source_files
      paths = Array.new(staging_paths.size) { staging_paths.pop }
      expect(paths.uniq.size).to eq(10)
    end

    context 'when a file cannot be downloaded' do
      before do
        allow(connector).to receive(:download_file).and_raise(Atc::Exceptions::SourceDownloadError, 'download failed')
      end

      it 'raises the error, without writing the manifest file' do
        expect { processor.download_and_process_source_files }.to raise_error(
          Atc::Exceptions::SourceDownloadError, 'download failed'
        )
        expect(File.exist?(manifest_file)).to be(false)
      end

      it 'stops starting new files once a file fails' do
        stub_const("#{described_class}::THREAD_COUNT", 1)
        expect { processor.download_and_process_source_files }.to raise_error(Atc::Exceptions::SourceDownloadError)
        expect(connector).to have_received(:download_file).once
      end
    end
  end
end
