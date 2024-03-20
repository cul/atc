# frozen_string_literal: true

module Atc::Loaders::ChecksumLoader
  def self.load(checksum_algorithm:, source_object_path:, checksum_value:, dry_run:, log_io:, enqueue_successor:)
    if dry_run
      # we're generous about checksum alg being missing on a dry run
      log_io.print("skip,#{checksum_algorithm&.name || 'MISSING'},#{checksum_value},#{source_object_path}\n")
      return
    end
    source_object =
      updatable_source_object(checksum_algorithm: checksum_algorithm,
                              source_object_path: source_object_path,
                              checksum_value: checksum_value,
                              dry_run: dry_run,
                              log_io: log_io)
    return unless source_object

    loggable_value = Atc::Utils::HexUtils.bin_to_hex(checksum_value)
    update_result = source_object.update(
      { fixity_checksum_value: checksum_value, fixity_checksum_algorithm: checksum_algorithm }
    )
    unless update_result
      log_io.print("fail,#{checksum_algorithm.name},#{loggable_value},#{source_object_path}\n")
      return
    end

    log_io.print("succ,#{checksum_algorithm.name},#{loggable_value},#{source_object_path}\n")
    PrepareTransferJob.perform_later(source_object.id, enqueue_successor: enqueue_successor) if enqueue_successor
  end

  # Returns true if the given checksum_algorithm and checksum_value
  # are both already assigned to the given source_object.
  def self.checksum_already_assigned?(source_object, checksum_algorithm, checksum_value)
    source_object.fixity_checksum_value == checksum_value &&
      source_object.fixity_checksum_algorithm == checksum_algorithm
  end

  def self.updatable_source_object(checksum_algorithm:, source_object_path:, checksum_value:, dry_run:, log_io:)
    loggable_value = Atc::Utils::HexUtils.bin_to_hex(checksum_value)

    # since whole object checksum algs have consistent length, we can sanity check proposed value
    if checksum_value.length != checksum_algorithm.empty_binary_value.length
      log_io.print("xval,#{checksum_algorithm.name},#{loggable_value},#{source_object_path}\n")
      return
    end

    if dry_run
      # we're generous about checksum alg being missing on a dry run
      log_io.print("skip,#{checksum_algorithm&.name || 'MISSING'},#{loggable_value},#{source_object_path}\n")
      return
    end

    source_object = SourceObject.for_path(source_object_path)
    unless source_object
      log_io.print("xsrc,#{checksum_algorithm.name},#{loggable_value},#{source_object_path}\n")
      return
    end

    if checksum_already_assigned?(source_object, checksum_algorithm, checksum_value)
      log_io.print("noop,#{checksum_algorithm.name},#{loggable_value},#{source_object_path}\n")
      return
    end

    source_object
  end
end
