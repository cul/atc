# frozen_string_literal: true

# rubocop:disable Style/MultilineIfModifier

# Ensures that this object's associated source_object has been assigned a fixity_checksum_value.
class PendingTransfer::SourceObjectChecksumValidator < ActiveModel::Validator
  def validate(record)
    return if record.source_object.nil?

    record.errors.add(
      :source_object, 'is missing a fixity_checksum_value (which is required for a transfer)'
    ) if record.source_object.fixity_checksum_value.nil?

    record.errors.add(
      :source_object, 'is missing a fixity_checksum_algorithm (which is required for a transfer)'
    ) if record.source_object.fixity_checksum_algorithm_id.nil?
  end
end
