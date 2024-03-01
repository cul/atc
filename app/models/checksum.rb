# frozen_string_literal: true

class Checksum < ApplicationRecord
  belongs_to :checksum_algorithm
  belongs_to :transfer_source
  validates :value, presence: true

  class HashOfNothingValidator < ActiveModel::Validator
    def validate(record)
      return if record.checksum_algorithm.nil?
      return unless record.value == record.checksum_algorithm.empty_value
      return if record.transfer_source.object_size.zero?

      record.errors.add :value, 'checksum value indicates no content for non-zero length file'
    end
  end
  validates_with HashOfNothingValidator
end
