# frozen_string_literal: true

require 'rails_helper'

describe Atc::Smb::Connector do
  let(:source_config) { { host: 'example.cul.columbia.edu', share: 'Groups', drive: 'L' } }
  let(:connector) { described_class.new(source_config: source_config) }
  let(:remote_dir) { '/existing-dir/subdir' }
  let(:local_path) { File.join(download_dir, 'file.txt') }
  let(:download_dir) { Dir.mktmpdir }

  let(:ls_output) do
    <<~LISTING
      \\existing-dir\\subdir
        .                                   D        0  Mon Sep  1 12:15:45 2026
        ..                                  D        0  Mon Sep  1 12:15:45 2026
        file.txt                            A       32  Mon Sep  1 12:15:45 2026
      \\existing-dir\\subdir\\nested
        nested-file.txt                     A       10  Mon Sep  1 12:15:45 2026
    LISTING
  end

  before { Retriable.configure { |config| config.sleep_disabled = true } }

  after do
    Retriable.configure { |config| config.sleep_disabled = false }
    FileUtils.remove_entry(download_dir)
  end

  def stub_smbclient(stdout: '', stderr: '', success: true)
    status = instance_double(Process::Status, success?: success)
    allow(Open3).to receive(:capture3).and_return([stdout, stderr, status])
  end

  def stub_smbclient_download(content)
    status = instance_double(Process::Status, success?: true)
    allow(Open3).to receive(:capture3) do
      File.write(local_path, content)
      ['', '', status]
    end
  end

  describe '.drive' do
    it 'returns the drive letter from the stabilization config' do
      expect(described_class.drive).to eq(STABILIZATION_CONFIG[:sources][:ldrive][:drive])
    end
  end

  describe '#smb_address' do
    it 'combines the host and the share' do
      expect(connector.smb_address).to eq('//example.cul.columbia.edu/Groups')
    end
  end

  describe '#list_files' do
    it 'returns a path and size for each file, relative to the listed directory' do
      stub_smbclient(stdout: ls_output)
      expect(connector.list_files(remote_dir)).to eq(
        [['/file.txt', 32], ['/nested/nested-file.txt', 10]]
      )
    end

    it 'leaves out directory entries' do
      stub_smbclient(stdout: ls_output)
      expect(connector.list_files(remote_dir).map(&:first)).not_to include('/.', '/..')
    end

    it 'accepts a directory given with backslashes' do
      stub_smbclient(stdout: ls_output)
      expect(connector.list_files('\\existing-dir\\subdir').map(&:first)).to eq(
        ['/file.txt', '/nested/nested-file.txt']
      )
    end

    it 'raises an error when the directory contains no files' do
      stub_smbclient(stdout: "\\existing-dir\\subdir\n")
      expect { connector.list_files(remote_dir) }.to raise_error(
        Atc::Exceptions::SourceListingError, /No files found/
      )
    end

    it 'raises an error when smbclient fails' do
      stub_smbclient(stderr: 'NT_STATUS_OBJECT_PATH_NOT_FOUND', success: false)
      expect { connector.list_files(remote_dir) }.to raise_error(
        Atc::Exceptions::SourceListingError, /Are you sure the directory exists\?/
      )
    end

    it 'raises an error when a file name cannot be decoded' do
      stub_smbclient(stdout: "  bad\xC3name.txt                       A       32  Mon Sep  1 12:15:45 2026\n")
      expect { connector.list_files(remote_dir) }.to raise_error(
        Atc::Exceptions::SourceListingError, /could not be decoded/
      )
    end
  end

  describe '#download_file' do
    it 'returns the local path that the file was downloaded to' do
      stub_smbclient_download('a' * 32)
      expect(connector.download_file(remote_dir, '/file.txt', local_path, expected_size: 32)).to eq(local_path)
    end

    it 'asks smbclient for the file, from the directory that it lives in' do
      stub_smbclient_download('a' * 32)
      connector.download_file(remote_dir, '/nested/file.txt', local_path, expected_size: 32)
      expect(Open3).to have_received(:capture3).with(
        'smbclient', connector.smb_address,
        '--authentication-file', described_class.auth_file_path.to_s,
        '-m', 'SMB3', '--use-kerberos=required',
        '-D', '/existing-dir/subdir/nested',
        '--command', %(get "file.txt" "#{local_path}")
      )
    end

    it 'raises an error when the downloaded file is incomplete' do
      stub_smbclient_download('a' * 10)
      expect {
        connector.download_file(remote_dir, '/file.txt', local_path, expected_size: 32)
      }.to raise_error(Atc::Exceptions::SourceDownloadError, /size mismatch/)
    end

    it 'tries again when a download fails for a reason that might be temporary' do
      stub_smbclient(stderr: 'NT_STATUS_IO_TIMEOUT', success: false)
      expect {
        connector.download_file(remote_dir, '/file.txt', local_path, expected_size: 32)
      }.to raise_error(Atc::Exceptions::SourceDownloadError)
      expect(Open3).to have_received(:capture3).exactly(described_class::DOWNLOAD_TRIES).times
    end

    it 'does not try again when the file is unavailable for a permanent reason' do
      stub_smbclient(stderr: 'NT_STATUS_ACCESS_DENIED', success: false)
      expect {
        connector.download_file(remote_dir, '/file.txt', local_path, expected_size: 32)
      }.to raise_error(Atc::Exceptions::SourceFileUnavailable, /error retrieving/)
      expect(Open3).to have_received(:capture3).once
    end
  end
end
