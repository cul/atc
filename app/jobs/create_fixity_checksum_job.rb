# frozen_string_literal: true

require 'digest'

class CreateFixityChecksumJob < ApplicationJob
  DEFAULT_CHECKSUM_ALGORITHM = 'SHA256'

  queue_as Atc::Queues::CREATE_FIXITY

  def perform(source_object_id, override: false, enqueue_successor: true)
    source_object = SourceObject.find(source_object_id)
    if source_object.fixity_checksum_value && !override
      enqueue_successor_jobs(source_object_id) if enqueue_successor
      return
    end

    fixity_checksum_algorithm = ChecksumAlgorithm.find_by!(name: DEFAULT_CHECKSUM_ALGORITHM)

    fixity_checksum_value = calculate_fixity_checksum(source_object, fixity_checksum_algorithm)
    return unless fixity_checksum_value

    source_object.update!(
      fixity_checksum_algorithm: fixity_checksum_algorithm, fixity_checksum_value: fixity_checksum_value
    )
    enqueue_successor_jobs(source_object_id) if enqueue_successor
  end

  def calculate_fixity_checksum(source_object, checksum_algorithm)
    return nil unless source_object && checksum_algorithm

    digester = Module.const_get("Digest::#{checksum_algorithm.name}")
    digester.new.file(source_object.path).digest
  rescue LoadError
    nil
  end

  def enqueue_successor_jobs(source_object_id)
    PrepareTransferJob.perform_later(source_object_id)
  end
end
