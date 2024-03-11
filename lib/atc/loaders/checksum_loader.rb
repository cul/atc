module Atc::Loaders::ChecksumLoader
  def self.load(checksum_algorithm:, source_object_path:, checksum_value:, dry_run:, log_io:)
    if dry_run
      # we're generous about checksum alg being missing on a dry run
      log_io.print("skip,#{checksum_algorithm&.name || 'MISSING'},#{checksum_value},#{source_object_path}\n")
      return
    end
    path_hash = Digest::SHA256.digest(source_object_path)
    source_object = SourceObject.find_by(path_hash: path_hash)
    unless source_object
      log_io.print("xsrc,#{checksum_algorithm.name},#{checksum_value},#{source_object_path}\n")
      return
    end

    if checksum_already_assigned?(source_object, checksum_algorithm, checksum_value)
      update_result = source_object.update(
        { fixity_checksum_value: checksum_value, fixity_checksum_algorithm: checksum_algorithm }
      )
      unless update_result
        log_io.print("fail,#{checksum_algorithm.name},#{checksum_value},#{source_object_path}\n")
        return
      end
    else
      log_io.print("noop,#{checksum_algorithm.name},#{checksum_value},#{source_object_path}\n")
      return
    end

    log_io.print("succ,#{checksum_algorithm.name},#{checksum_value},#{source_object_path}\n")
  end

  # Returns true if the given checksum_algorithm and checksum_value
  # are both already assigned to the given source_object.
  def checksum_already_assigned?(source_object, checksum_algorithm, checksum_value)
    source_object.fixity_checksum_value == checksum_value && fixity_checksum_algorithm == checksum_algorithm
  end
end
