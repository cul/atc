# frozen_string_literal: true

class Atc::AipReader
  SUPPORTED_CHECKSUM_ALGORITHMS_IN_ORDER_OF_PREFERENCE = ['sha256', 'sha512', 'md5'].freeze

  attr_reader :path, :manifest_file_path, :tagmanifest_file_path, :checksum_type, :file_path_to_checksum_map

  def initialize(aip_path, verbose: false)
    @verbose = verbose
    @path = aip_path
    @file_list = self.class.generate_file_list(self.path)
    @manifest_file_path, @tagmanifest_file_path = select_best_manifest_files
    validate!
    @checksum_type = @manifest_file_path.match(/.+-(.+).txt/)[1]
    generate_file_path_to_checksum_map!
    ensure_file_list_checksum_coverage!
  end

  # Iterates over each file in this AIP, yielding the full file path and checksum.
  # @yield [file_path, checksum]
  def each_file_with_checksum(&block)
    file_path_to_checksum_map.each(&block)
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
      raise Atc::Exceptions::UnreadableAip,
            "The following files could not be read:\n#{unreadable_files.sort.join("\n")}"
    end

    readable_files
  end

  # @visibility private
  # This method ensures that all files in @file_list have a corresponding checksum and raises an error if any files
  # do not have a checksum.
  def ensure_file_list_checksum_coverage!
    files_without_checksums = []
    @file_list.each do |file_path|
      files_without_checksums << file_path unless file_path_to_checksum_map.key?(file_path)
    end

    return if files_without_checksums.empty?

    raise Atc::Exceptions::MissingAipChecksums,
          "The following files did not have associated checksums in the manifest or tagmanifest files:\n#{files_without_checksums.sort.join("\n")}"
  end

  # @visibility private
  # Generates the file path to checksum map for this AIP and assigns it to @file_path_to_checksum_map.
  # This method uses the manifest and tagmanifest files to generate a mapping of AIP files to associated checksums.
  # A checksum is also dynamically generated for the tagmanifest file because its checksum would not appear in the
  # manifest or tagmanifest files.
  def generate_file_path_to_checksum_map!
    file_paths_to_checksums = {}
    counter = 0
    print 'Generating AIP checksum mapping (0)...' if @verbose
    [self.tagmanifest_file_path, self.manifest_file_path].each do |checksum_source_file|
      File.foreach(checksum_source_file) do |line|
        checksum, aip_relative_path = line.strip.split(' ', 2)
        file_paths_to_checksums[File.join(self.path, aip_relative_path)] = checksum
        print "\rGenerating AIP checksum mapping (#{counter += 1})..." if @verbose
      end
    end
    puts '' if @verbose

    # And we'll manually generate a checksum for the tagmanifest file, since it doesn't contain its own checksum
    file_paths_to_checksums[self.tagmanifest_file_path] =
      "Digest::#{self.checksum_type.upcase}".constantize.file(self.tagmanifest_file_path).hexdigest

    @file_path_to_checksum_map = file_paths_to_checksums
  end

  # @visibility private
  # Returns true if this is a valid AIP.
  def validate!
    if self.manifest_file_path.nil?
      raise Atc::Exceptions::InvalidAip,
            'Could not find supported manifest file (need sha256, sha512, or md5).'
    end

    if self.tagmanifest_file_path.nil?
      raise Atc::Exceptions::InvalidAip,
            "Could not find tagmanifest file with checksum algorithm matching manifest file: #{tagmanifest_file_path}"
    end

    validate_aip_content_glob_patterns!
  end

  # @visibility private
  # Checks to see if this AIP has the minimum set of expected files and subdirectories.
  def validate_aip_content_glob_patterns!
    glob_patterns_to_check = ['data', 'bagit.txt', 'bag-info.txt', 'manifest-*.txt', 'tagmanifest-*.txt'].map do |val|
      File.join(self.path, val)
    end

    missing = glob_patterns_to_check.select { |expected_file_or_directory| Dir.glob(expected_file_or_directory).blank? }

    return if missing.empty?

    raise Atc::Exceptions::InvalidAip,
          "The following expected files/directories are missing from this AIP: #{missing.sort.join("\n")}"
  end

  # @visibility private
  # Selects the best manifest files available, preferring sha256 first, then sha512, and then md5.
  # Other checksum algorithms are not supported at this time and will be ignored.
  # @return [Array] An array of two elements: the first is the manifest file path and the second is a tagmanifest path.
  #                 If no supported-algorithm manifest file is found, the first element will be nil.  The tagmanifest
  #                 path will be for a file that matches the checksum algorithm of the manifest file, or will be nil
  #                 if a matching checksum algorithm file cannot be found.(if a supported manifest file is found)
  def select_best_manifest_files
    manifest_and_tagmanifest_paths = [nil, nil]

    manifest_algorithm = SUPPORTED_CHECKSUM_ALGORITHMS_IN_ORDER_OF_PREFERENCE.find do |checksum_algorithm|
      next File.exist?(manifest_path_for_checksum_algorithm(checksum_algorithm))
    end

    return manifest_and_tagmanifest_paths if manifest_algorithm.nil?

    manifest_and_tagmanifest_paths[0] = manifest_path_for_checksum_algorithm(manifest_algorithm)
    possible_tagmanifest_path = tagmanifest_path_for_checksum_algorithm(manifest_algorithm)
    manifest_and_tagmanifest_paths[1] = possible_tagmanifest_path if File.exist?(possible_tagmanifest_path)

    manifest_and_tagmanifest_paths
  end

  # @visibility private
  # Generates the full path to the manifest file for the given checksum algorithm.
  def manifest_path_for_checksum_algorithm(checksum_algorithm)
    File.join(self.path, "manifest-#{checksum_algorithm}.txt")
  end

  # @visibility private
  # Generates the full path to the tagmanifest file for the given checksum algorithm.
  def tagmanifest_path_for_checksum_algorithm(checksum_algorithm)
    File.join(self.path, "tagmanifest-#{checksum_algorithm}.txt")
  end
end
