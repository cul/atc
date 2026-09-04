# frozen_string_literal: true

# Collects file path + checksum pairs to write to manifest-sha256.txt as files are uploaded
# The manifest is complete once all files have been uploaded to the cloud
class Atc::Smb::ManifestWriter
  attr_reader :manifest_file, :file_count, :byte_count

  def initialize(stabilization_dir: SMB_CONFIG[:stabilization_dir])
    @manifest_file = File.join(stabilization_dir, 'manifest-sha256.txt')
    @file_count = 0
    @byte_count = 0
  end

  def start
    File.write(@manifest_file, '')
    @file_count = 0
    @byte_count = 0
  end

  def add_row(checksum, normalized_path, size)
    File.open(@manifest_file, 'a') do |file|
      file.puts("#{checksum}  data/#{normalized_path}")
    end

    @file_count += 1
    @byte_count += size
  end

  # The "Payload-Oxum" value for bag-info.txt
  def payload_oxum
    "#{@byte_count}.#{@file_count}"
  end
end
