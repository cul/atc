# frozen_string_literal: true

# Collects file path + checksum pairs to write to manifest-sha256.txt as files are uploaded
# The manifest is complete once all files have been uploaded to the cloud
class Atc::Bag::PayloadManifest
  attr_reader :manifest_file, :file_count, :byte_count

  # bag_dir is the local directory that the bag's tag files are written to
  # layout determines file paths recorded by the manifest
  def initialize(bag_dir:, layout:)
    @manifest_file = File.join(bag_dir, 'manifest-sha256.txt')
    @layout = layout
    @file_count = 0
    @byte_count = 0

    # Synchronize access to the manifest file and counters so it can be used safely across multiple threads
    @semaphore = Mutex.new
  end

  def start
    @semaphore.synchronize do
      File.write(@manifest_file, '')
      @file_count = 0
      @byte_count = 0
    end
  end

  def add_row(checksum, normalized_path, size)
    @semaphore.synchronize do
      File.open(@manifest_file, 'a') do |file|
        file.puts("#{checksum}  #{@layout.payload_path(normalized_path)}")
      end

      @file_count += 1
      @byte_count += size
    end
  end

  # The "Payload-Oxum" value for bag-info.txt
  def payload_oxum
    "#{@byte_count}.#{@file_count}"
  end
end
