# frozen_string_literal: true

require 'rails_helper'

describe Atc::Utils::FileUtils do
  describe '.stream_recursive_directory_read' do
    let(:test_dir_with_files) { Rails.root.join('tmp/file-utils-test-dir') }
    let(:sample_file_paths) do
      [
        '.dotfile',
        'file1.txt',
        'file2.txt',
        'file3.txt',
        'subdirectory1/file1.txt',
        'subdirectory1/file2.txt',
        'subdirectory1/file3.txt',
        'subdirectory2/file1.txt',
        'subdirectory2/file2.txt',
        'subdirectory2/file3.txt',
        'subdirectory3/.dotfile'
      ].map { |relative_path| File.join(test_dir_with_files, relative_path) }
    end

    before do
      FileUtils.rm_rf(test_dir_with_files) if File.exist?(test_dir_with_files)
      sample_file_paths.each do |sample_file_path|
        FileUtils.mkdir_p(File.dirname(sample_file_path))
        FileUtils.touch(sample_file_path)
      end
    end

    it 'yields the expected results' do
      results = []
      described_class.stream_recursive_directory_read(test_dir_with_files) { |file_path| results << file_path }
      expect(results.sort).to eq(sample_file_paths.sort)
    end

    it 'reports unreadable directories' do
      unreadable_dir_path = File.join(test_dir_with_files, 'unreadable-dir1')
      expect(Dir).to receive(:foreach).with(unreadable_dir_path).and_raise(Errno::EACCES, unreadable_dir_path)

      unreadable_directory_path_error_list = []
      described_class.stream_recursive_directory_read(unreadable_dir_path, unreadable_directory_path_error_list)
      expect(unreadable_directory_path_error_list.length).to eq(1)
      expect(unreadable_directory_path_error_list.first).to include(unreadable_dir_path)
    end
  end
end
