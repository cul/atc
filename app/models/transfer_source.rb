require 'digest'

class TransferSource < ApplicationRecord
	has_one :repository, required: false
	validates :path, presence: { strict: true }, on: :create

	def path_hash!
		self.path_hash ||= begin
			raise "cannot compute hash on nil path" unless path
			TransferSource.binary_hash(path)
		end
	end

	def self.unhex(value)
		return nil unless value =~ /^([0-9a-fA-F]{2})*$/
		value.scan(/../).map { |chunk| chunk.hex }.pack('c*')
	end

    def self.binary_hash(value)
		unhex Digest::SHA2.new(256).hexdigest(value)
    end

	class PathValidator < ActiveModel::Validator
		def validate(record)
			return unless record.changed_attributes.include? :path

			record.errors.add :path, "path cannot be updated after source creation"
		end
	end
	class PathHashValidator < ActiveModel::Validator
		def validate(record)
			return if record.path_hash! == TransferSource.binary_hash(record.path)

			record.errors.add :path_hash, "path_hash does not match calculated value"
		end
	end
	validates_with PathValidator, on: :update
	validates_with PathHashValidator
end