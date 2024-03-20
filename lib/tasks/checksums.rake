# frozen_string_literal: true
require 'csv'

namespace :atc do
  namespace :checksums do
    def parse_boolean_argument(arg, default = false)
      ENV.fetch(arg, default.to_s) == 'true'
    end

    def parse_enqueue_successor_argument
      parse_boolean_argument('enqueue_successor')
    end

    def parse_dry_run_argument
      parse_boolean_argument('dry_run')
    end

    desc 'load checksums from a CSV'
    task csv: :environment do
      csv_path = ENV['path']
      dry_run = parse_dry_run_argument()
      enqueue_successor = parse_enqueue_successor_argument()

      # seed checksum cache with most likely
      sha256_checksum_algorithm = ChecksumAlgorithm.find_by!(name: 'SHA256')
      checksum_algorithms = {
        sha256_checksum_algorithm.name => sha256_checksum_algorithm
      }

      start = Time.now
      open("log/checksum-csv-#{start.to_i}#{'-dry_run' if dry_run}.log", "w") do |log|
        CSV.foreach(csv_path, headers: true).each do |row|
          # checksum_algorithm_name,checksum_value,source_object_path
          checksum_algorithm_name = row['checksum_algorithm_name']
          # For consistency, always store SHA256 checksum value as downcased hex string
          checksum_value = checksum_algorithm_name == sha256_checksum_algorithm.name ? row['checksum_value'].downcase : row['checksum_value']
          source_object_path = row['source_object_path']
          checksum_algorithm = (checksum_algorithms[checksum_algorithm_name] ||= ChecksumAlgorithm.find_by(name: checksum_algorithm_name))
          Atc::Loaders::ChecksumLoader.load(
            checksum_algorithm: checksum_algorithm,
            source_object_path: source_object_path,
            checksum_value: checksum_value,
            dry_run: dry_run,
            log_io: log,
            enqueue_successor: enqueue_successor
          )
        end
      end
    end

    desc 'Pull SHA256 checksums from an Archivematica AIP'
    task aip: :environment do
      dry_run = parse_dry_run_argument()
      aip_path = ENV['path']
      unless ENV["debug"] || aip_path.start_with?("/digital/preservation")
        puts Rainbow("Cautiously declining: #{aip_path}").red
        return
      end

      if File.directory?(aip_path)
        manifests = Dir.glob("*sha256.txt", base: aip_path)
      elsif aip_path =~ /sha256.txt$/
        aip_path = File.dirname(aip_path)
        manifests = Dir.glob("*sha256.txt", base: aip_path)
      end

      unless manifests&.length > 0
        puts Rainbow("This doesn't look like an AIP: #{aip_path}").red
        return
      end

      checksum_algorithm = ChecksumAlgorithm.find_by(name: 'SHA256')
      start = Time.now
      open("log/checksum-aip-#{start.to_i}#{'-dry_run' if dry_run}.log", "w") do |log|
        manifests.each do |manifest_path|
          open(File.join(aip_path, manifest_path)) do |io|
            io.each do |line|
              line.strip!
              # For consistency, always store SHA256 checksum value as downcased hex string
              checksum_value, rel_path = line.split(' ').downcase
              rel_path = rel_path.sub(/^\.\//, '')
              source_object_path = File.join(aip_path, rel_path)
              Atc::Loaders::ChecksumLoader.load(
                checksum_algorithm: checksum_algorithm,
                source_object_path: source_object_path,
                checksum_value: checksum_value,
                dry_run: dry_run,
                start_time: start,
                log_io: log
              )
            end
          end
        end
      end
    end

    # TODO: Remove this later, since it's just a temporary task that's useful for early testing.
    desc "Generates and saves a sha256 fixity checksum value for the specified SourceObject (if it doesn't have a checksum value already)"
    task generate: :environment do
      source_object_id = ENV['source_object_id']

      unless source_object_id.match?(/[0-9]+/)
        puts 'source_object_id must be an integer value'
        next
      end

      source_object = SourceObject.find(source_object_id)
      if source_object.fixity_checksum_value.present?
        puts 'SourceObject already has a fixity checksum value. Nothing to do here.'
        next
      end
      sha256_checksum_algorithm = ChecksumAlgorithm.find_by(name: 'SHA256')
      source_object.fixity_checksum_algorithm = sha256_checksum_algorithm
      source_object.fixity_checksum_value = Digest::SHA256.file(source_object.path).digest
      if source_object.save
        puts Rainbow('Checksum successfully added to SourceObject!').green
      else
        puts Rainbow("The following errors occurred while attempting to assign a checksum value: #{source_object.errors.full_messages}").red
      end
    end
  end
end
