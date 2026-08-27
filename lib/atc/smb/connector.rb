# frozen_string_literal: true

require 'open3'
require 'tempfile'

class Atc::Smb::Connector
  # Matches a single entry in the output of smbclient's `ls` command
  LS_ENTRY_REGEX = /\A {2}(?<name>.+?) +(?<attributes>[A-Z]+) +(?<size>\d+) +(?<modified_at>\w{3} \w{3} +\d{1,2} \d{2}:\d{2}:\d{2} \d{4})\s*\z/ # rubocop:disable Layout/LineLength

  # Matches the header line that smbclient prints before going intothe contents of each subdirectory
  DIR_HEADER_REGEX = /\A\\(?<path>.*\S)\s*\z/

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

  # Remote dir is a directory on the share
  def list(remote_dir)
    # TODO: We should place this file under a folder that indicates what share folder this csv was generated for
    csv_dir = "#{SMB_CONFIG[:stabilization_dir]}/output.csv"
    CSV.open(csv_dir, 'w') do |csv|
      csv << ['file_path']

      each_file(remote_dir) { |file_path| csv << [file_path] }
    end
  end

  # Recursively iterates over every file under remote_dir (a directory on the share).
  def each_file(remote_dir, &block)
    base_dir = normalize_path(remote_dir)
    with_auth_file do |auth_file_path|
      get_file_paths(base_dir, ls_output(base_dir, auth_file_path), &block)
    end
  end

  private

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

  # Yields the path of every file in a recursive listing, relative to base_dir
  def get_file_paths(base_dir, output)
    relative_dir = ''
    output.each_line do |line|
      if (header = DIR_HEADER_REGEX.match(line))
        relative_dir = normalize_path(header[:path]).delete_prefix(base_dir)
      elsif (entry = LS_ENTRY_REGEX.match(line)) && !entry[:attributes].include?('D')
        yield "#{relative_dir}/#{entry[:name]}"
      end
    end
  end

  # Converts an SMB path to a "/dir/subdir" form
  def normalize_path(path)
    segments = path.to_s.tr('\\', '/').split('/').reject(&:empty?)
    segments.empty? ? '' : "/#{segments.join('/')}"
  end

  def ls_output(remote_dir, auth_file_path)
    command = smbclient_command(remote_dir, auth_file_path)
    puts "Running: #{command.join(' ')}"
    stdout, stderr, status = Open3.capture3(*command)

    raise "error while listing #{remote_dir}: #{stderr.strip}" unless status.success?

    stdout
  end

  def smbclient_command(remote_dir, auth_file_path)
    ['smbclient', "//#{@host}/#{@share}", '--authentication-file', auth_file_path,
     '-m', 'SMB3', '--use-kerberos=required', '-D', remote_dir, '--command', 'recurse ON; ls']
  end
end
