class MoveChecksumsToSourceObjects < ActiveRecord::Migration[7.1]
  def change
    # Transfer all checksum values to the source_objects table
    checksum_count = Checksum.count
    num_processed = 0
    start_time = Time.now
    puts "Transferring checksum values to the source_objects table..."
    Checksum.includes(:source_object).find_in_batches(batch_size: 5000) do |checksum_batch|
      source_object_batch_updates = {}
      checksum_batch.each do |checksum|
        source_object_batch_updates[checksum.source_object.id] = {
          fixity_checksum_algorithm_id: checksum.checksum_algorithm_id,
          fixity_checksum_value: checksum.value
        }
      end
      # NOTE: Doing direct queries below is about 5x faster than:
      # SourceObject.update(source_object_batch_updates.keys, source_object_batch_updates.values)
      source_object_batch_updates.each do |source_object_id, update_data|
        # NOTE: We only have hex checksums in our prod data checksums table right now,
        # so it's okay to assume all checksum values are hex.
        ActiveRecord::Base.connection.exec_query(
          'UPDATE source_objects '\
          "SET fixity_checksum_algorithm_id = #{update_data[:fixity_checksum_algorithm_id]}, "\
          "fixity_checksum_value = UNHEX('#{update_data[:fixity_checksum_value]}') "\
          "WHERE id = #{source_object_id}"
        )
      end
      num_processed += checksum_batch.count
      print "\rProcessed: #{num_processed} of #{checksum_count} (in #{(Time.now - start_time).to_i} seconds)"
    end
    print "\rProcessed: #{num_processed} of #{checksum_count} (in #{(Time.now - start_time).to_i} seconds)"
    puts "\nDone!"

    # Now that we've transferred all checksum values to the source_objects table,
    # we can drop the checksums table.
    drop_table :checksums
  end
end
