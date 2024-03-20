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

    # Yields one or more source_id integer values based on available ENV values.
    # Reads from one of the following ENV values (using whichever one it finds first):
    # source_object_id, source_object_path, source_object_id_file
    #
    # ENV['source_object_id'] - A single SourceObject id
    # ENV['source_object_path'] - A SourceObject path value
    # ENV['source_object_id_file'] - A file that contains a list of SourceObject ids, with one id per line
    #
    # @return [Boolean] true if at least one source_id is available based on the ENV values,
    #                   otherwise prints an error message to stdout and returns false.
    def with_source_id_argument
      if ENV['source_object_id'].present?
        value = ENV['source_object_id']
        unless value.match?(/[0-9]+/)
          puts "Error: source_object_id must be an integer value"
          return false
        end
        yield value.to_i
      elsif ENV['source_object_path'].present?
        id = SourceObject.for_path(ENV['source_object_path'])&.id
        unless id.present?
          puts "Error: could not find a SourceObject with the given source_object_path"
          return false
        end
        yield id
      elsif ENV['source_object_id_file'].present?
        source_object_id_file = ENV['source_object_id_file']
        unless File.exist?(source_object_id_file)
          puts "Error: File not found at #{source_object_id_file}"
          return false
        end
        # First, validate all of the ids (to make sure they're all numeric ids)
        puts 'Validating source_object_id_file...'
        File.foreach(source_object_id_file) do |line|
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
        File.foreach(source_object_id_file) do |line|
          # Using String#strip because each line has a new line character at the end
          line_content = line.strip
          next if line_content.empty?
          yield line.strip.to_i
        end
      else
        puts 'Please specify one or more source ids, using one of the following arguments: '\
              'source_object_id, source_object_path, source_object_id_file'
        return false
      end

      true
    end

    desc "Queue a CreateFixityChecksumJob that can optionally enqueue successor jobs. "\
          "This job calculates and stores a fixity checksum for a SourceObject."
    task create_fixity_checksum: :environment do
      enqueue_successor = parse_enqueue_successor_argument()

      next unless with_source_id_argument() do |source_object_id|
        puts "Queued source_object_id: #{source_object_id}"
        CreateFixityChecksumJob.perform_later(source_object_id, enqueue_successor: enqueue_successor)
      end

      puts 'Done'
    end

    desc "Queue a PrepareTransferJob that can optionally enqueue successor jobs. "\
          "This job creates PendingTransfers for a SourceObject."
    task prepare_transfer: :environment do
      enqueue_successor = parse_enqueue_successor_argument()

      next unless with_source_id_argument() do |source_object_id|
        puts "Queued source_object_id: #{source_object_id}"
        PrepareTransferJob.perform_later(source_object_id, enqueue_successor: enqueue_successor)
      end

      puts 'Done'
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
