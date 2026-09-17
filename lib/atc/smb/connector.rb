# frozen_string_literal: true

require 'open3'

class Atc::Smb::Connector
  # Matches a single entry in the output of smbclient's `ls` command
  LS_ENTRY_REGEX = /\A {2}(?<name>.+?) +(?<attributes>[A-Z]+) +(?<size>\d+) +(?<modified_at>\w{3} \w{3} +\d{1,2} \d{2}:\d{2}:\d{2} \d{4})\s*\z/ # rubocop:disable Layout/LineLength

  # Matches the header line that smbclient prints before going intothe contents of each subdirectory
  DIR_HEADER_REGEX = /\A\\(?<path>.*\S)\s*\z/

  # Matches the status code that smbclient prints when it can't read an individual file or directory
  NT_STATUS_ERROR_REGEX = /NT_STATUS_(?!OK\b)\w+/

  # The drive letter (eg. 'L')
  def self.drive
    STABILIZATION_CONFIG[:sources][:ldrive][:drive]
  end

  # This class only ever connects to the ldrive source. Other source types (eg. googledrive)
  # are not implemented yet (see Atc::Stabilization::TaskArgs::IMPLEMENTED_SOURCE_TYPES).
  def initialize(source_config: STABILIZATION_CONFIG[:sources][:ldrive])
    @host = source_config[:host]
    @share = source_config[:share]
  end

  def smb_address
    "//#{@host}/#{@share}"
  end

  # Recursively lists every file under remote_dir (a directory on the share).
  # Returns an Array of [file_path, size] pairs where file_path is relative to remote_dir.
  def list_files(remote_dir)
    base_dir = normalize_path(remote_dir)
    files = parse_ls_output(base_dir, ls_output(base_dir))

    raise Atc::Exceptions::SourceListingError, "No files found under #{smb_address}#{base_dir}" if files.empty?

    files
  end

  # Downloads a single file from remote_dir (a directory on the share) to local_path,
  # verifies that the whole file arrived and returns local_path
  def download_file(remote_dir, file_path, local_path, expected_size:)
    smbclient_get(remote_dir, file_path, local_path)
    verify_download_size(file_path, local_path, expected_size)
    local_path
  end

  def self.auth_file_path
    Rails.root.join('config/l-drive-auth')
  end

  private

  # Verify size since smbclient can exit successfully even if the file is incomplete
  def verify_download_size(file_path, local_path, expected_size)
    actual_size = File.size(local_path)
    return if actual_size == expected_size

    raise "size mismatch for #{file_path}: expected #{expected_size} bytes, downloaded #{actual_size}"
  end

  # Runs smbclient's `get` command to copy a single file to the given local_path
  def smbclient_get(remote_dir, file_path, local_path)
    path_with_share = "#{remote_dir}#{File.dirname(file_path)}"
    source_filename = File.basename(file_path)

    puts "Path with share: #{path_with_share}"
    puts "Source filename: #{source_filename}"
    puts "Local path: #{local_path}"

    command = smbclient_command(path_with_share, "get \"#{source_filename}\" \"#{local_path}\"")
    puts "Running: #{command.join(' ')}"
    _stdout, stderr, status = Open3.capture3(*command)
    puts "Finished running command for #{file_path}, success=#{status.success?}"

    raise "error retrieving #{file_path}: #{stderr.strip}" unless status.success?

    local_path
  end

  # Returns an Array of [file_path, size] pairs for every file in a recursive listing,
  # with paths relative to base_dir
  def parse_ls_output(base_dir, output)
    # Treat partial listings as errors so we don't accidentally operate on incomplete data
    errors = output.each_line.select { |line| line.match?(NT_STATUS_ERROR_REGEX) }.map(&:strip)

    if errors.any?
      raise Atc::Exceptions::SourceListingError,
            "Not everything under #{base_dir} could be listed:\n#{errors.join("\n")}"
    end

    parse_file_entries(base_dir, output)
  end

  def parse_file_entries(base_dir, output)
    relative_dir = ''
    files = []

    output.each_line do |line|
      if (header = DIR_HEADER_REGEX.match(line))
        relative_dir = normalize_path(header[:path]).delete_prefix(base_dir)
      elsif (entry = LS_ENTRY_REGEX.match(line)) && !entry[:attributes].include?('D')
        files << ["#{relative_dir}/#{entry[:name]}", entry[:size].to_i]
      end
    end

    files
  end

  # Converts an SMB path to a "/dir/subdir" form
  def normalize_path(path)
    segments = path.to_s.tr('\\', '/').split('/').reject(&:empty?)
    segments.empty? ? '' : "/#{segments.join('/')}"
  end

  def ls_output(remote_dir)
    command = smbclient_command(remote_dir, 'recurse ON; ls')
    puts "Running: #{command.join(' ')}"
    stdout, stderr, status = Open3.capture3(*command)

    unless status.success?
      raise Atc::Exceptions::SourceListingError,
            "error while listing #{remote_dir}: #{stderr.strip}. Are you sure the directory exists?"
    end

    output = "#{stdout}\n#{stderr}"
    validate_encoding!(output)
    output
  end

  # Reject listings with invalid encoding so that we don't attempt to process undecodable file names
  def validate_encoding!(output)
    return if output.valid_encoding?

    undecodable = output.each_line.reject(&:valid_encoding?).map { |line| line.scrub.strip }
    raise Atc::Exceptions::SourceListingError,
          "Some names in the listing could not be decoded:\n#{undecodable.join("\n")}"
  end

  def smbclient_command(remote_dir, smb_command)
    # Kerberos is not required but no other authentication method is allowed for this command
    ['smbclient', smb_address, '--authentication-file', self.class.auth_file_path.to_s,
     '-m', 'SMB3', '--use-kerberos=required', '-D', remote_dir, '--command', smb_command]
  end
end
