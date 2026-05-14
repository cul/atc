# frozen_string_literal: true

# This file houses our custom errors
module Exceptions
  class InvalidBucketError < StandardError; end
  class InvalidKeyName < StandardError; end
end
