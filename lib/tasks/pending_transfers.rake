namespace :atc do
  namespace :pending_transfers do

    desc "Queue a CreatePendingTransferJob"
    task :from_source_object do
      source_object_id = ENV['source_object_id']
      if source_object_id is_a? Integer
        CreatePendingTransferJob.perform_later source_object_id.to_i
      end
    end
  end
end
