namespace :atc do
  namespace :pending_transfers do

    desc "Queue a CreatePendingTransferJob"
    task :from_transfer_source do
      transfer_source_record_id = ENV[‘transfer_source_id’]
      if transfer_source_record_id.present?
        CreatePendingTransferJob.perform_later transfer_source_record_id.to_i
      end
    end
  end
end
