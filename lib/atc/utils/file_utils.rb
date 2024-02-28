module Atc::Utils::FileUtils
  # Recursively read the files in a directory by streaming the read operations
  # instead of trying to gather and load all of them into memory at the same time.
  # @param dir [String] Path to the directory to scan
  # @param unreadable_directory_paths_list [Array] An optional array to pass in, which if provided
  #        will be filled with a list of all unreadable directories that are encountered.
  def self.stream_recursive_directory_read(dir, unreadable_directory_path_error_list = nil, &block)
    Dir.foreach(dir) do |filename|
      next if filename == '.' or filename == '..'
      full_file_or_directory_path = File.join(dir, filename)
      if File.file?(full_file_or_directory_path)
        block.call(full_file_or_directory_path)
      else
        stream_recursive_directory_read(full_file_or_directory_path, unreadable_directory_path_error_list, &block)
      end
    end
  rescue Errno::EACCES => e
    # Encountered an unreadable directory! Store the error message and continue.
    unreadable_directory_path_error_list << e.message unless unreadable_directory_path_error_list.nil?
  end
end
