# frozen_string_literal: true

require 'digest'

class Atc::Smb::BagAssembler
  # Everything transferred by this process comes from the L Drive for now
  CONTENT_SOURCE_TYPE = 'L-Drive'

  def initialize(
    source_dir:,
    payload_oxum:, manifest_file:, normalization_log_file:,
    non_success_files:, repository_name: 'TODO', collection_name: 'TODO',
    stabilization_dir: SMB_CONFIG[:stabilization_dir]
  )
    @source_dir = source_dir
    @payload_oxum = payload_oxum
    @manifest_file = manifest_file
    @normalization_log_file = normalization_log_file
    @repository_name = repository_name
    @collection_name = collection_name
    @stabilization_dir = stabilization_dir
    @non_success_files = non_success_files
  end

  def write_tag_files
    File.write(bagit_file, "BagIt-Version: 1.0\nTag-File-Character-Encoding: UTF-8\n")
    File.write(bag_info_file, bag_info_content)
    # The tag manifest holds checksums of other tag files so it has to be written last
    File.write(tag_manifest_file, tag_manifest_content)
  end

  def tag_files
    checksummed_tag_files + [tag_manifest_file]
  end

  private

  def checksummed_tag_files
    [bagit_file, bag_info_file, @manifest_file, @normalization_log_file]
  end

  def bag_info_content
    bag_info = {
      'Bagging-Date' => Time.zone.today.strftime('%Y-%m-%d'),
      'Payload-Oxum' => @payload_oxum,
      'Content-Source-Type' => CONTENT_SOURCE_TYPE,
      'Content-Source-Path' => @source_dir,
      'Repository-Name' => @repository_name,
      'Collection-Name' => @collection_name,
      'Virus-Check-Result' => @non_success_files.empty? ? 'PASS' : 'FAIL'
    }

    content = bag_info.map { |label, value| "#{label}: #{value}\n" }
    content.concat(@non_success_files.keys.map { |file| "Virus-Check-Failed-File: #{file}\n" })
    content.join
  end

  def tag_manifest_content
    checksummed_tag_files.map { |file| "#{Digest::SHA256.file(file).hexdigest}  #{File.basename(file)}\n" }.join
  end

  def bagit_file
    File.join(@stabilization_dir, 'bagit.txt')
  end

  def bag_info_file
    File.join(@stabilization_dir, 'bag-info.txt')
  end

  def tag_manifest_file
    File.join(@stabilization_dir, 'tagmanifest-sha256.txt')
  end
end
