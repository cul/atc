# frozen_string_literal: true

class Atc::DirectoryReader
  attr_reader :path, :file_list

  def initialize(aip_path, verbose: false)
    @verbose = verbose
    @path = aip_path
    @file_list = self.class.generate_file_list(self.path).sort
  end

  # Iterates over each file in this directory, yielding the full file path.
  # @yield file_path
  def each_file(&block)
    file_list.each(&block)
  end

  # @visibility private
  # Iterates over all files in the AIP (regardless of whether they appear in the manifest or tagmanifest files)
  # and returns an array with all paths.  If any unreadable files are encountered, an error is raised with a message
  # that details which files could not be read.
  def self.generate_file_list(directory_path)
    readable_files = []
    unreadable_files = []
    counter = 0
    print 'Generating file list (0)...' if @verbose
    Atc::Utils::FileUtils.stream_recursive_directory_read(directory_path) do |file_path|
      if File.readable?(file_path)
        readable_files << file_path
      else
        unreadable_files << file_path
      end
      print "\rGenerating file list (#{counter += 1})..." if @verbose
    end
    puts '' if @verbose

    if unreadable_files.length.positive?
      raise Atc::Exceptions::UnreadableFiles,
            "The following files could not be read:\n#{unreadable_files.sort.join("\n")}"
    end

    readable_files
  end
end
