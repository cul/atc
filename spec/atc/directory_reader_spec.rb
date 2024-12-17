# frozen_string_literal: true

require 'rails_helper'

describe Atc::DirectoryReader do
  subject(:directory_reader) { described_class.new(path_to_directory_fixture_copy) }

  let(:path_to_directory_fixture_copy) do
    tmpdir_path = Dir.mktmpdir('sample_directory_')
    # copy the CONTENTS of path_to_directory_fixture to tmpdir_path
    FileUtils.cp_r("#{file_fixture('sample_directory')}/.", tmpdir_path)
    tmpdir_path
  end

  let(:expected_file_list) do
    [
      File.join(path_to_directory_fixture_copy, '/sample-file1.txt'),
      File.join(path_to_directory_fixture_copy, '/sample-file2.txt')
    ]
  end

  before do
    # There should not be any .DS_Store files in our directory fixture, so we'll delete them before our tests run.
    # If any are present, they were unintentionally created when the directory was viewed on macOS.
    Dir.glob("#{path_to_directory_fixture_copy}/**/.DS_Store").each do |ds_store_file|
      File.delete(ds_store_file)
    end
  end

  after do
    # The line below is just a safety measure to make sure that FileUtils.rm_rf is only used on the expected
    # directory, since it could be destructive if an error is ever introduced to this test code.
    unless path_to_directory_fixture_copy.start_with?(Dir.tmpdir)
      raise "Temp directory found at location other than tmpdir path: #{path_to_directory_fixture_copy}"
    end

    FileUtils.rm_rf(path_to_directory_fixture_copy)
  end

  describe '#initialize' do
    it 'instantiates a new DirectoryReader when a valid directory path is supplied' do
      expect(directory_reader).to be_a(described_class)
    end

    it 'generates the expected file_list' do
      expect(directory_reader.file_list.sort).to eq(expected_file_list)
    end
  end

  describe '.generate_file_list' do
    it 'returns the expected file list when all files are readable' do
      expect(described_class.generate_file_list(path_to_directory_fixture_copy).sort).to eq(expected_file_list.sort)
    end

    it 'raises an exception when some files in the directory are not readable, '\
        'and the error message lists the unreadable files' do
      # all files readable by default
      allow(File).to receive(:readable?).and_return(true)
      # pretend that sample-file1.txt is not readable
      allow(File).to receive(:readable?).with(
        File.join(path_to_directory_fixture_copy, 'sample-file1.txt')
      ).and_return(false)
      # pretend that sample-file2.txt is not readable
      allow(File).to receive(:readable?).with(
        File.join(path_to_directory_fixture_copy, 'sample-file2.txt')
      ).and_return(false)
      expect {
        described_class.generate_file_list(path_to_directory_fixture_copy)
      }.to raise_error(
        Atc::Exceptions::UnreadableFiles,
        "The following files could not be read:\n"\
        "#{File.join(path_to_directory_fixture_copy, 'sample-file1.txt')}\n"\
        "#{File.join(path_to_directory_fixture_copy, 'sample-file2.txt')}"
      )
    end
  end
end
