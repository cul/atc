# frozen_string_literal: true

require 'rails_helper'

describe Atc::AipReader do
  subject(:aip_reader) { described_class.new(path_to_aip_fixture_copy) }

  let(:path_to_aip_fixture_copy) do
    tmpdir_path = Dir.mktmpdir('sample_aip_')
    FileUtils.cp_r("#{file_fixture('sample_aip')}/.", tmpdir_path) # copy the CONTENTS of path_to_aip_fixture to tmpdir_path
    tmpdir_path
  end

  let(:expected_file_path_to_checksum_map) do
    {
      File.join(path_to_aip_fixture_copy, '/bag-info.txt') => '8dcde95d24d5679687cd543d4f3483ffbcfcf477fcdb9d8d8a8e8ced1b5f8760',
      File.join(path_to_aip_fixture_copy, '/bagit.txt') => 'e91f941be5973ff71f1dccbdd1a32d598881893a7f21be516aca743da38b1689',
      File.join(path_to_aip_fixture_copy, '/data/METS.4558310f-9573-457b-bee9-6b2cd354b51e.xml') => 'e8f79f085d4aa9dcaf235575afd4f8f3c7733c54ec5e2c16a41cf5ee73cfb229',
      File.join(path_to_aip_fixture_copy, '/data/README.html') => 'ceddea13574d8e0b6715aeb05d091b4e93feb6d3b7da71d9d15610bebe865248',
      File.join(path_to_aip_fixture_copy, '/data/logs/fileFormatIdentification.log') => '47f503eb481872d7c3b2a3024eec7386ecc07b6343436f7d92b6f09fde330ce4',
      File.join(path_to_aip_fixture_copy, '/data/logs/filenameCleanup.log') => 'a8580d090b716442f2d31ac8a0753750b38fdda7e82f14d7ebac5e725233d7e8',
      File.join(path_to_aip_fixture_copy, '/data/logs/transfers/sample_1-99254175-7b00-474b-ac29-3b2a04a04901/logs/fileFormatIdentification.log') => '61fad71d335751b04a84d8270bbbf0ee4c50732e3bb6bb7050ecb7ab9b9ad8cb',
      File.join(path_to_aip_fixture_copy, '/data/logs/transfers/sample_1-99254175-7b00-474b-ac29-3b2a04a04901/logs/filenameCleanup.log') => '1f9c114a262c6b715eedd5b7ce4fac40747320ab8aa7e3e408044b9080e8e611',
      File.join(path_to_aip_fixture_copy, '/data/objects/metadata/transfers/sample_1-99254175-7b00-474b-ac29-3b2a04a04901/directory_tree.txt') => '84ce6b3cb87d4c810975a88e1a24c87db8e4668ada11a6034a764d634d8466d9',
      File.join(path_to_aip_fixture_copy, '/data/objects/sample-file.txt') => '11586d2eb43b73e539caa3d158c883336c0e2c904b309c0c5ffe2c9b83d562a1',
      File.join(path_to_aip_fixture_copy, '/data/objects/submissionDocumentation/transfer-sample_1-99254175-7b00-474b-ac29-3b2a04a04901/METS.xml') => '8136cc8231084326cfcfe34b764e82330e61196a87fade6c1dd9d5423c5f3fc0',
      File.join(path_to_aip_fixture_copy, '/data/thumbnails/058fedd0-e412-43d7-85a5-ac93c7efb4d6.jpg') => '9333d3f3739e2cebc856c3bb1d9cd7471115b091e17c5fcd649d7db599ff672a',
      File.join(path_to_aip_fixture_copy, '/manifest-sha256.txt') => 'ec5f749fcdd93d85f5d606b9607e056c40c28beb7ffcf1de0df998fffc2fca8d',
      File.join(path_to_aip_fixture_copy, '/tagmanifest-sha256.txt') => '892d92ab06f32a4f533b62877b11bc879d508c26019e67868d57b77ae17b814f'
    }
  end

  before do
    # There should not be any .DS_Store files in our aip fixture, so we'll delete them before our tests run.
    # If any are present, they were unintentionally created when the directory was viewed on macOS.
    Dir.glob("#{path_to_aip_fixture_copy}/**/.DS_Store").each do |ds_store_file|
      File.delete(ds_store_file)
    end
  end

  after do
    # The line below is just a safety measure to make sure that FileUtils.rm_rf is only used on the expected
    # directory, since it could be destructive if an error is ever introduced to this test code.
    unless path_to_aip_fixture_copy.start_with?(Dir.tmpdir)
      raise "Temp aip found at location other than tmpdir path: #{path_to_aip_fixture_copy}"
    end

    FileUtils.rm_rf(path_to_aip_fixture_copy)
  end

  describe '#initialize' do
    it 'instantiates a new AipReader when a valid aip path is supplied' do
      expect(aip_reader).to be_a(described_class)
    end

    it 'raises an exception when a manifest file is missing' do
      File.delete(File.join(path_to_aip_fixture_copy, 'manifest-sha256.txt'))
      expect { aip_reader }.to raise_error(Atc::Exceptions::InvalidAip)
    end

    it 'raises an exception when a tagmanifest file is missing' do
      File.delete(File.join(path_to_aip_fixture_copy, 'tagmanifest-sha256.txt'))
      expect { aip_reader }.to raise_error(Atc::Exceptions::InvalidAip)
    end

    it 'raises an exception when a data directory is missing' do
      FileUtils.rm_rf(File.join(path_to_aip_fixture_copy, 'data'))
      expect { aip_reader }.to raise_error(Atc::Exceptions::InvalidAip)
    end

    it 'raises an exception when a bagit.txt file is missing' do
      File.delete(File.join(path_to_aip_fixture_copy, 'bagit.txt'))
      expect { aip_reader }.to raise_error(Atc::Exceptions::InvalidAip)
    end

    it 'raises an exception when a bag-info.txt file is missing' do
      File.delete(File.join(path_to_aip_fixture_copy, 'bag-info.txt'))
      expect { aip_reader }.to raise_error(Atc::Exceptions::InvalidAip)
    end

    it 'raises an exception when a manifest file exists, but no same-algorithm tagmanifest file exists' do
      FileUtils.mv(
        File.join(path_to_aip_fixture_copy, 'tagmanifest-sha256.txt'),
        File.join(path_to_aip_fixture_copy, 'tagmanifest-md5.txt')
      )
      expect { aip_reader }.to raise_error(Atc::Exceptions::InvalidAip)
    end

    it 'raises an exception when a manifest file exists, but uses an unsupported checksum algorithm' do
      FileUtils.mv(
        File.join(path_to_aip_fixture_copy, 'manifest-sha256.txt'),
        File.join(path_to_aip_fixture_copy, 'manifest-sha123.txt')
      )
      expect { aip_reader }.to raise_error(Atc::Exceptions::InvalidAip)
    end

    it 'generates the expected file_path_to_checksum_map' do
      expect(aip_reader.file_path_to_checksum_map).to eq(expected_file_path_to_checksum_map)
    end

    it 'includes a checksum for the tagmanifest file in the file_path_to_checksum_map (which is dynamically generated because it cannot be extracted from the manifest or tagmanifest files)' do
      expect(
        aip_reader.file_path_to_checksum_map[File.join(aip_reader.path, 'tagmanifest-sha256.txt')]
      ).to eq('892d92ab06f32a4f533b62877b11bc879d508c26019e67868d57b77ae17b814f')
    end

    it 'raises an exception if any files in the AIP directory (other than the tagmanifest file) do not have checksums in the manifest or tagmanifest files' do
      FileUtils.cp(
        File.join(path_to_aip_fixture_copy, 'data/objects/sample-file.txt'),
        File.join(path_to_aip_fixture_copy, 'data/objects/sample-file2.txt')
      )
      FileUtils.cp(
        File.join(path_to_aip_fixture_copy, 'data/objects/sample-file.txt'),
        File.join(path_to_aip_fixture_copy, 'data/objects/sample-file3.txt')
      )
      expect { aip_reader }.to raise_error(
        Atc::Exceptions::MissingAipChecksums,
        "The following files did not have associated checksums in the manifest or tagmanifest files:\n"\
        "#{File.join(path_to_aip_fixture_copy, 'data/objects/sample-file2.txt')}\n"\
        "#{File.join(path_to_aip_fixture_copy, 'data/objects/sample-file3.txt')}"
      )
    end
  end

  describe '.generate_file_list' do
    it 'returns the expected file list when all files are readable' do
      expect(described_class.generate_file_list(path_to_aip_fixture_copy).sort).to eq(expected_file_path_to_checksum_map.keys.sort)
    end

    it 'raises an exception when some files in the AIP are not readable, and the error message lists the unreadable files' do
      # all files readable by default
      allow(File).to receive(:readable?).and_return(true)
      # pretend that bagit.txt is not readable
      allow(File).to receive(:readable?).with(File.join(path_to_aip_fixture_copy, 'bagit.txt')).and_return(false)
      # pretend that data/README.html is not readable
      allow(File).to receive(:readable?).with(File.join(path_to_aip_fixture_copy, 'data/README.html')).and_return(false)
      expect {
        described_class.generate_file_list(path_to_aip_fixture_copy)
      }.to raise_error(
        Atc::Exceptions::UnreadableAip,
        "The following files could not be read:\n"\
        "#{File.join(path_to_aip_fixture_copy, 'bagit.txt')}\n"\
        "#{File.join(path_to_aip_fixture_copy, 'data/README.html')}"
      )
    end
  end
end
