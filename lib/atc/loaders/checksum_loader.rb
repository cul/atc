# frozen_string_literal: true

module Atc::Loaders::ChecksumLoader
  def self.load(checksum_algorithm:, source_object_path:, checksum_value:, dry_run:, log_io:, start_time:)
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

    checksum = Checksum.find_or_create_by(
      value: checksum_value, source_object: source_object, checksum_algorithm: checksum_algorithm
    )
    unless checksum
      log_io.print("fail,#{checksum_algorithm.name},#{checksum_value},#{source_object_path}\n")
      return
    end

    if checksum.created_at.to_time < start_time
      log_io.print("noop,#{checksum_algorithm.name},#{checksum_value},#{source_object_path}\n")
      return
    end
    log_io.print("succ,#{checksum_algorithm.name},#{checksum_value},#{source_object_path}\n")
  end
end
