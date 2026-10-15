# frozen_string_literal: true

require 'fileutils'

# Collects file path + checksum pairs to write to manifest-sha256.txt as files are uploaded
# Rows are collected in an unordered file first, since files can finish uploading in any order.
# The manifest is complete once all files have been uploaded to the cloud and finalize has written
# manifest-sha256.txt in the order of the inventory.
class Atc::Bag::PayloadManifest
  attr_reader :manifest_file, :file_count, :byte_count

  # bag_dir is the local directory that the bag's tag files are written to
  # layout determines file paths recorded by the manifest
  def initialize(bag_dir:, layout:)
    @manifest_file = File.join(bag_dir, 'manifest-sha256.txt')
    @unordered_file = File.join(bag_dir, 'unordered-payload-manifest.tmp')
    @layout = layout
    @file_count = 0
    @byte_count = 0

    # Synchronize access to the manifest file and counters so it can be used safely across multiple threads
    @semaphore = Mutex.new
  end

  def start
    @semaphore.synchronize do
      FileUtils.rm_f(@manifest_file)
      File.write(@unordered_file, '')
      @file_count = 0
      @byte_count = 0
    end
  end

  def add_row(checksum, normalized_path, size)
    @semaphore.synchronize do
      File.open(@unordered_file, 'a') do |file|
        file.puts("#{checksum}  #{normalized_path}")
      end

      @file_count += 1
      @byte_count += size
    end
  end

  # Writes the final manifest-sha256.txt with one row for each of normalized_paths, in the same order
  # as they appear in the inventory.csv
  def finalize(normalized_paths)
    @semaphore.synchronize do
      checksums = recorded_checksums
      ordered_file = "#{@manifest_file}.partial"

      File.open(ordered_file, 'w') { |file| write_ordered_rows(file, normalized_paths, checksums) }

      if checksums.any?
        raise Atc::Exceptions::PayloadManifestError,
              "Checksums were recorded for files missing from the inventory: #{checksums.keys.join(', ')}"
      end

      File.rename(ordered_file, @manifest_file)
    end
  end

  # The "Payload-Oxum" value for bag-info.txt
  def payload_oxum
    "#{@byte_count}.#{@file_count}"
  end

  private

  # Returns a hash of normalized_path => checksum for every row
  def recorded_checksums
    File.foreach(@unordered_file).each_with_object({}) do |line, checksums|
      checksum, normalized_path = line.chomp.split('  ', 2)
      if checksums.key?(normalized_path)
        raise Atc::Exceptions::PayloadManifestError, "More than one checksum was recorded for #{normalized_path}"
      end

      checksums[normalized_path] = checksum
    end
  end

  def write_ordered_rows(file, normalized_paths, checksums)
    normalized_paths.each do |normalized_path|
      checksum = checksums.delete(normalized_path)
      raise Atc::Exceptions::PayloadManifestError, "No checksum was recorded for #{normalized_path}" unless checksum

      file.puts("#{checksum}  #{@layout.payload_path(normalized_path)}")
    end
  end
end
