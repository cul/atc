# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tempfile'

class Atc::Smb::Connector
  # Matches a single entry in the output of smbclient's `ls` command
  LS_ENTRY_REGEX = /\A {2}(?<name>.+?) +(?<attributes>[A-Z]+) +(?<size>\d+) +(?<modified_at>\w{3} \w{3} +\d{1,2} \d{2}:\d{2}:\d{2} \d{4})\s*\z/ # rubocop:disable Layout/LineLength

  # Matches the header line that smbclient prints before going intothe contents of each subdirectory
  DIR_HEADER_REGEX = /\A\\(?<path>.*\S)\s*\z/

  def initialize(source_config:, stabilization_dir: SMB_CONFIG[:stabilization_dir])
    @host = source_config[:host]
    @share = source_config[:share]
    @username = source_config[:username]
    @password = source_config[:password]
    @domain = source_config[:domain]
    @stabilization_dir = stabilization_dir
  end

  # Recursively lists every file under remote_dir (a directory on the share).
  # Returns an Array of [file_path, size] pairs where file_path is relative to remote_dir.
  def list_files(remote_dir)
    base_dir = normalize_path(remote_dir)
    with_auth_file do |auth_file_path|
      parse_ls_output(base_dir, ls_output(base_dir, auth_file_path))
    end
  end

  # Downloads files from remote_dir (a directory on the share) one at a time
  def each_downloaded_file(remote_dir, files)
    with_auth_file do |auth_file_path|
      files.each do |file_path, normalized_path, size|
        local_path = download_file(remote_dir, file_path, normalized_path, auth_file_path)
        verify_download_size(file_path, local_path, size)
        yield local_path, normalized_path, size
      end
    end
  end

  private

  # Verify size since smbclient can exit successfully even if the file is incomplete
  def verify_download_size(file_path, local_path, expected_size)
    actual_size = File.size(local_path)
    return if actual_size == expected_size

    raise "size mismatch for #{file_path}: expected #{expected_size} bytes, downloaded #{actual_size}"
  end

  # Downloads a file under its normalized path
  def download_file(remote_dir, file_path, normalized_path, auth_file_path)
    path_with_share = "#{remote_dir}#{File.dirname(file_path)}"
    source_filename = File.basename(file_path)
    local_path = temp_path_for(normalized_path)

    puts "Path with share: #{path_with_share}"
    puts "Source filename: #{source_filename}"
    puts "Local path: #{local_path}"

    command = smbclient_command(path_with_share, auth_file_path, "get \"#{source_filename}\" \"#{local_path}\"")
    puts "Running: #{command.join(' ')}"
    _stdout, stderr, status = Open3.capture3(*command)
    puts "Finished running command for #{file_path}, success=#{status.success?}"

    raise "error retrieving #{file_path}: #{stderr.strip}" unless status.success?

    local_path
  end

  def temp_path_for(normalized_path)
    local_path = File.join(@stabilization_dir, normalized_path)
    FileUtils.mkdir_p(File.dirname(local_path))
    local_path
  end

  # Generate a temporary authentication file so that the password is not exposed
  # on the command line
  def with_auth_file
    file = Tempfile.new('smb-auth')
    file.write("username=#{@username}\npassword=#{@password}\ndomain=#{@domain}\n")
    file.close
    yield file.path
  ensure
    file&.unlink
  end

  # Returns an Array of [file_path, size] pairs for every file in a recursive listing,
  # with paths relative to base_dir
  def parse_ls_output(base_dir, output)
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

  def ls_output(remote_dir, auth_file_path)
    # TODO: Validate that the output matches the format we expect so the regex doesn't break
    command = smbclient_command(remote_dir, auth_file_path, 'recurse ON; ls')
    puts "Running: #{command.join(' ')}"
    stdout, stderr, status = Open3.capture3(*command)

    raise "error while listing #{remote_dir}: #{stderr.strip}" unless status.success?

    stdout
  end

  def smbclient_command(remote_dir, auth_file_path, smb_command)
    ['smbclient', "//#{@host}/#{@share}", '--authentication-file', auth_file_path,
     '-m', 'SMB3', '--use-kerberos=required', '-D', remote_dir, '--command', smb_command]
  end
end
