# frozen_string_literal: true

class Atc::Smb::Connector
  def initialize
    sock = TCPSocket.new(SMB_CONFIG[:host], 445)
    dispatcher = RubySMB::Dispatcher::Socket.new(sock, read_timeout: 60)

    smb_client = RubySMB::Client.new(
      dispatcher,
      username: SMB_CONFIG[:username],
      password: SMB_CONFIG[:password],
      domain: SMB_CONFIG[:domain]
    )

    smb_client.negotiate
    status = smb_client.authenticate
    Rails.logger.info("Authentication status: #{status}")
    Rails.logger.info("Negotiated dialect #{smb_client.dialect}")
  end
end
