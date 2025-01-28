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

    def with_source_object_id_argument(&block)
      with_id_argument('source_object', &block)
    end

    def with_pending_transfer_id_argument(&block)
      with_id_argument('pending_transfer', &block)
    end

    def with_stored_object_id_argument(&block)
      with_id_argument('stored_object', &block)
    end

    # Yields one or more id integer values based on available ENV values.
    # Reads from one of the following ENV values (using whichever one it finds first):
    # "#{prefix}_id", "#{prefix}_id_file", "source_object_path"
    #
    # ENV["#{prefix}_id"] - A single id
    # ENV["#{prefix}_id_file"] - A file that contains a list of ids, with one id per line
    # ENV["source_object_path"] - A SourceObject path value that will be resolved to a SourceObject id via DB lookup.
    #
    # @return [Boolean] true if at least one source_id is available based on the ENV values,
    #                   otherwise prints an error message to stdout and returns false.
    def with_id_argument(prefix)
      if ENV["#{prefix}_id"].present?
        value = ENV["#{prefix}_id"]
        unless value.match?(/[0-9]+/)
          puts "Error: #{prefix}_id must be an integer value"
          return false
        end
        yield value.to_i
      elsif ENV["#{prefix}_id_file"].present?
        id_file = ENV["#{prefix}_id_file"]
        unless File.exist?(id_file)
          puts "Error: File not found at #{id_file}"
          return false
        end
        # First, validate all of the ids (to make sure they're all numeric ids)
        puts "Validating #{prefix}_id_file..."
        File.foreach(id_file) do |line|
          # Using String#strip because each line has a new line character at the end
          line_content = line.strip
          unless line_content.empty? || line.strip =~ /^\d+$/
            puts "Error: Encountered invalid id: #{line}"
            return false
          end
          line
        end
        puts 'Validation passed.'
        # Then actually yield each id
        File.foreach(id_file) do |line|
          # Using String#strip because each line has a new line character at the end
          line_content = line.strip
          next if line_content.empty?
          yield line.strip.to_i
        end
      elsif ENV['source_object_path'].present?
        source_object_id = SourceObject.for_path(ENV['source_object_path'])&.id

        unless source_object_id.present?
          puts 'Error: could not find a SourceObject with the given source_object_path'
          return false
        end
        yield id
      else
        puts 'Please specify one or more source ids, using one of the following arguments: '\
              "#{prefix}_id, #{prefix}_id_file"
        return false
      end

      true
    end

    desc "Queue a CreateFixityChecksumJob that can optionally enqueue successor jobs. "\
          "This job calculates and stores a fixity checksum for a SourceObject."
    task create_fixity_checksum: :environment do
      enqueue_successor = parse_enqueue_successor_argument()

      next unless with_source_object_id_argument() do |source_object_id|
        puts "Queued source_object_id: #{source_object_id}"
        CreateFixityChecksumJob.perform_later(source_object_id, enqueue_successor: enqueue_successor)
      end

      puts 'Done'
    end

    desc "Queue a PrepareTransferJob that can optionally enqueue successor jobs. "\
          "This job creates PendingTransfers for a SourceObject."
    task prepare_transfer: :environment do
      enqueue_successor = parse_enqueue_successor_argument()
      run_again = ENV['run_again'] == 'true'

      next unless with_source_object_id_argument() do |source_object_id|
        puts "Queued source_object_id: #{source_object_id}"
        if run_again
          PendingTransfer.destroy_by(source_object_id: source_object_id)
        end
        PrepareTransferJob.perform_later(source_object_id, enqueue_successor: enqueue_successor)
      end

      puts 'Done'
    end

    desc "Queue a PerformTransferJob. "\
          "This job converts a PendingTransfer to a StoredObject while transferring a file."
    task perform_transfer: :environment do
      next unless with_pending_transfer_id_argument() do |pending_transfer_id|
        puts "Queued pending_transfer_id: #{pending_transfer_id}"
        PerformTransferJob.perform_later(pending_transfer_id)
      end

      puts 'Done'
    end

    desc "Queue a VerifyFixityJob. "\
          "This job verifies the fixity for a given StoredObject"
    task verify_fixity: :environment do
      next unless with_stored_object_id_argument() do |stored_object_id|
        puts "Queued stored_object_id: #{stored_object_id}"
        VerifyFixityJob.perform_later(stored_object_id)
      end

      puts 'Done'
    end
  end
end
