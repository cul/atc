module Atc::Loaders::ChecksumLoader
  def self.load(checksum_algorithm:, transfer_source_path:, checksum_value:, dry_run:, log_io:)
    if dry_run
      # we're generous about checksum alg being missing on a dry run
      log_io.print("skip,#{checksum_algorithm&.name || 'MISSING'},#{checksum_value},#{transfer_source_path}\n")
      return
    end
    path_hash = Digest::SHA256.digest(transfer_source_path)
    transfer_source = TransferSource.find_by(path_hash: path_hash)
    unless transfer_source
      log_io.print("xsrc,#{checksum_algorithm.name},#{checksum_value},#{transfer_source_path}\n")
      return
    end
    unless checksum = Checksum.find_or_create_by(value: checksum_value, transfer_source: transfer_source, checksum_algorithm: checksum_algorithm)
      log_io.print("fail,#{checksum_algorithm.name},#{checksum_value},#{transfer_source_path}\n")
      return
    end
    if checksum.created_at.to_time < start_time
      log_io.print("noop,#{checksum_algorithm.name},#{checksum_value},#{transfer_source_path}\n")
      return
    end
    log_io.print("succ,#{checksum_algorithm.name},#{checksum_value},#{transfer_source_path}\n")
  end
end