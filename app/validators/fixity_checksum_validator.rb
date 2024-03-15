# frozen_string_literal: true

class FixityChecksumValidator < ActiveModel::Validator
  def validate(record)
    # If record has no fixity_checksum_algorithm, there's nothing to validate
    return if record.fixity_checksum_algorithm.nil?

    if record.object_size.zero?
      validate_checksum_for_zero_byte_file(record)
    else
      validate_checksum_for_positive_size_file(record)
    end
  end

  def validate_checksum_for_zero_byte_file(record)
    return if record.fixity_checksum_value == record.fixity_checksum_algorithm.empty_binary_value

    record.errors.add(
      :fixity_checksum_value,
      'object size is zero bytes, but checksum value does not match zero-byte checksum'
    )
  end

  def validate_checksum_for_positive_size_file(record)
    return if record.fixity_checksum_value != record.fixity_checksum_algorithm.empty_binary_value

    record.errors.add(
      :fixity_checksum_value,
      'checksum value indicates zero-byte object, but object size is greater than zero bytes'
    )
  end
end
