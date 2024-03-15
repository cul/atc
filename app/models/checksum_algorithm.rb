# frozen_string_literal: true

class ChecksumAlgorithm < ApplicationRecord
  validates :empty_binary_value, presence: true
end
