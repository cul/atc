# frozen_string_literal: true

require 'digest'

class CreateFixityChecksumJob < ApplicationJob
  DEFAULT_CHECKSUM_ALGORITHM = 'SHA256'

  queue_as Atc::Queues::CREATE_FIXITY

  def perform(source_object_id, override = nil)
    source_object = SourceObject.find(source_object_id)
    return false if source_object.fixity_checksum_value && !override

    checksum_algorithm_name = DEFAULT_CHECKSUM_ALGORITHM
    fixity_checksum_algorithm = ChecksumAlgorithm.find_by!(name: checksum_algorithm_name)

    fixity_checksum_value = calculate_fixity_checksum(source_object, fixity_checksum_algorithm)
    return unless fixity_checksum_value

    source_object.update!(
      fixity_checksum_algorithm: fixity_checksum_algorithm, fixity_checksum_value: fixity_checksum_value
    )
  end

  def calculate_fixity_checksum(source_object, checksum_algorithm)
    return nil unless source_object && checksum_algorithm

    digester = Module.const_get("Digest::#{checksum_algorithm.name}")
    digester.new.file(source_object.path).digest
  rescue LoadError
    nil
  end
end
