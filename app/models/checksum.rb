class Checksum < ApplicationRecord
	belongs_to :checksum_algorithm
	belongs_to :transfer_source

  class HashOfNothingValidator < ActiveModel::Validator
  	def validate(record)
  		return unless record.value == record.checksum_algorithm.empty_value
  		return if record.transfer_source.object_size == 0
		record.errors.add :value, "checksum value indicates no content for non-zero length file"
  	end
  end
  validates_with HashOfNothingValidator
end
