# frozen_string_literal: true

class Atc::Smb::Connector
  def initialize(host: SMB_CONFIG[:host], share: SMB_CONFIG[:share], username: SMB_CONFIG[:username])
    @host = host
    @share = share
    @username = username
  end

  # Remote dir is a directory on the share
  def list(remote_dir)
    command = smbclient_command(remote_dir)
    puts "Running: #{command}"
    output = `#{command} 2>&1`
    puts output
    output
  end

  private

  # Relies on Kerberos ticket. Change to use a password.
  def smbclient_command(remote_dir)
    "smbclient //#{@host}/#{@share} --user #{@username} -m SMB3 " \
      "--use-kerberos=required --no-pass -D #{remote_dir.shellescape} --command ls"
  end
end
