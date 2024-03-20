namespace :atc do
  namespace :queue do

    def parse_integer_argument(env_key)
      value = ENV[env_key]
      if value.nil?
        puts "Missing required argument: #{env_key}"
        return nil
      end
      unless value.match?(/[0-9]+/)
        puts "#{env_key} must be an integer value"
        nil
      end
      value.to_i
    end

    def parse_enqueue_successor_argument
      ENV['enqueue_successor'] == 'true'
    end

    desc "Queue a CreateFixityChecksumJob that can optionally enqueue successor jobs. "\
          "This job calculates and stores a fixity checksum for a SourceObject."
    task create_fixity_checksum: :environment do
      source_object_id = parse_integer_argument('source_object_id')
      next if source_object_id.nil?
      enqueue_successor = parse_enqueue_successor_argument()

      CreateFixityChecksumJob.perform_later(source_object_id, enqueue_successor: enqueue_successor)
    end

    desc "Queue a PrepareTransferJob that can optionally enqueue successor jobs. "\
          "This job creates PendingTransfers for a SourceObject."
    task prepare_transfer: :environment do
      source_object_id = parse_integer_argument('source_object_id')
      next if source_object_id.nil?
      enqueue_successor = parse_enqueue_successor_argument()

      PrepareTransferJob.perform_later(source_object_id.to_i, enqueue_successor: enqueue_successor)
    end

    desc "Queue a PerformTransferJob. "\
          "This job converts a PendingTransfer to a StoredObject while transferring a file."
    task perform_transfer: :environment do
      pending_transfer_id = parse_integer_argument('pending_transfer_id')
      next if pending_transfer_id.nil?

      PerformTransferJob.perform_later(pending_transfer_id.to_i)
    end
  end
end
