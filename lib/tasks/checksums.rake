# frozen_string_literal: true
require 'csv'

namespace :atc do
  namespace :checksums do
    desc 'load checksums from a CSV'
    task csv: :environment do
      dry_run = ENV['dry_run'] == 'true'
      csv_path = ENV['path']
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
            start_time: start,
            log_io: log
          )
        end
      end
    end
    desc 'Pull SHA256 checksums from an Archivematica AIP'
    task aip: :environment do
      dry_run = ENV['dry_run'] == 'true'
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
  end
end
