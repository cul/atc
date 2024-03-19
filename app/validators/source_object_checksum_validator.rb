# frozen_string_literal: true

# Ensures that this object's associated source_object has been assigned a fixity_checksum_value.
class SourceObjectChecksumValidator < ActiveModel::Validator
  def validate(record)
    return if record.source_object&.fixity_checksum_value&.present?

    record.errors.add(
      :source_object,
      'is missing a fixity_checksum_value (which is required for a transfer)'
    )
  end
end
