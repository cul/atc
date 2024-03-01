# frozen_string_literal: true

class ChecksumAlgorithm < ApplicationRecord
  validates :empty_value, presence: true
end
