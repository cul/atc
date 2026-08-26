# frozen_string_literal: true

require 'open3'
require 'tempfile'

class Atc::Smb::Connector
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
    with_auth_file do |auth_file_path|
      command = smbclient_command(remote_dir, auth_file_path)
      puts "Running: #{command.join(' ')}"
      output = Open3.capture2e(*command).first
      puts output
      output
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

  def smbclient_command(remote_dir, auth_file_path)
    ['smbclient', "//#{@host}/#{@share}", '--authentication-file', auth_file_path,
     '-m', 'SMB3', '--use-kerberos=required', '-D', remote_dir, '--command', 'ls']
  end
end
