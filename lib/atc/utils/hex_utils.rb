module Atc::Utils::HexUtils
  # Converts the given hex string to a binary string
  def self.unhex(hex_string)
    return nil unless /^([0-9a-fA-F]{2})*$/.match?(hex_string)
    hex_string.scan(/../).map(&:hex).pack('c*')
  end
end
