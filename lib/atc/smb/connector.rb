# frozen_string_literal: true

require 'open3'
require 'tempfile'

class Atc::Smb::Connector
  # Matches a single entry in the output of smbclient's `ls` command
  LS_ENTRY_REGEX = /\A {2}(?<name>.+?) +(?<attributes>[A-Z]+) +(?<size>\d+) +(?<modified_at>\w{3} \w{3} +\d{1,2} \d{2}:\d{2}:\d{2} \d{4})\s*\z/ # rubocop:disable Layout/LineLength

  # Matches the header line that smbclient prints before going intothe contents of each subdirectory
  DIR_HEADER_REGEX = /\A\\(?<path>.*\S)\s*\z/

  # TODO: Store the share folder for later use
  def initialize(
    host: SMB_CONFIG[:host],
    share: SMB_CONFIG[:share],
    username: SMB_CONFIG[:username],
    password: SMB_CONFIG[:password],
    domain: SMB_CONFIG[:domain]
  )
    @host = host
    @share = share
    @username = username
    @password = password
    @domain = domain
  end

  # Recursively lists every file under remote_dir (a directory on the share).
  # Returns an Array of [file_path, size] pairs where file_path is relative to remote_dir.
  def list_files(remote_dir)
    base_dir = normalize_path(remote_dir)
    with_auth_file do |auth_file_path|
      parse_ls_output(base_dir, ls_output(base_dir, auth_file_path))
    end
  end

  # Downloads files from remote_dir (a directory on the share). `files` is an enumerable of
  # [file_path, normalized_path] pairs.
  # TODO: Implement the upload part after downloading the files (outside of this method)
  def get_and_upload_files(remote_dir, files)
    with_auth_file do |auth_file_path|
      files.each do |file_path, normalized_path|
        download_file(remote_dir, file_path, normalized_path, auth_file_path)
      end
    end
  end

  private

  # TODO: specify a different path for downloaded files
  def download_file(remote_dir, file_path, normalized_path, auth_file_path)
    path_with_share = "#{remote_dir}#{File.dirname(file_path)}"
    source_filename = File.basename(file_path)
    normalized_filename = File.basename(normalized_path)

    puts "Path with share: #{path_with_share}"
    puts "Source filename: #{source_filename}"
    puts "Normalized filename: #{normalized_filename}"

    # When downloading, renames the file to its normalized name
    command = smbclient_command(path_with_share, auth_file_path, "get #{source_filename} #{normalized_filename}")
    puts "Running: #{command.join(' ')}"
    _stdout, stderr, status = Open3.capture3(*command)
    puts "Finished running command for #{file_path}, success=#{status.success?}"

    raise "error retrieving #{file_path}: #{stderr.strip}" unless status.success?
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
