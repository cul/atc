# frozen_string_literal: true

module Atc::Exceptions
  class AtcError < StandardError; end
  class TransferError < AtcError; end
  class ObjectExists < AtcError; end
end
