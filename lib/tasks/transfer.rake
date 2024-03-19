namespace :atc do
  namespace :transfer do

    desc "Queue generation of PendingTransfer records for the specified SourceObject"
    task prepare: :environment do
      source_object_id = ENV['source_object_id']

      unless source_object_id.match?(/[0-9]+/)
        puts 'source_object_id must be an integer value'
        next
      end

      PrepareTransferJob.perform_later(source_object_id.to_i)
    end

    desc "Queue a transfer for the specified PendingTransfer record"
    task perform: :environment do
      pending_transfer_id = ENV['pending_transfer_id']

      unless pending_transfer_id.match?(/[0-9]+/)
        puts 'pending_transfer_id must be an integer value'
        next
      end

      PerformTransferJob.perform_later(pending_transfer_id.to_i)
    end
  end
end
