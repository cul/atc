# frozen_string_literal: true

require 'fileutils'

# Downloads a finalized bag out of the stabilization bucket and validates it
class Atc::Stabilization::BagRetriever
  def initialize(bucket:, bag_root_prefix:, download_dir:)
    @bucket = bucket
    @bag_root_prefix = bag_root_prefix
    @download_dir = download_dir
    # The bag is downloaded as its own basename under the download directory
    @bag_path = File.join(@download_dir, @bag_root_prefix)
  end

  # Returns true when the bag was downloaded and is valid
  def retrieve
    return false unless download_location_available?

    download_bag
    validate_bag
  end

  private

  # Guards against writing into an existing bag directory. With the current implementation this should
  # never happen because every bag name contains a YYYYMMDD_HHMMSS timestamp.
  def download_location_available?
    return true unless Dir.exist?(@bag_path)

    report_failure("Couldn't download bag", "The directory #{@bag_path} already exists.")
    false
  end

  def download_bag
    puts "Downloading to #{@download_dir}"
    Atc::Aws::S3Downloader.new(@bucket, @download_dir).download_directory(@bag_root_prefix)
  end

  def validate_bag
    puts "Checking downloaded bag under #{@bag_path}"
    validator = Atc::Bag::Validator.new(@bag_path)

    unless validator.valid?
      report_failure('Failed to download bag', "The bag downloaded to #{@bag_path} is not valid:\n#{validator.errors.join("\n")}")
      return false
    end

    puts "#{@bag_path} is valid"
    StabilizationMailer.notify('Successfully downloaded bag', "The bag was successfully downloaded to #{@bag_path}.")
    # TODO: Delete the bag from AWS stabilization directory
    true
  end

  def report_failure(subject, message)
    puts message
    StabilizationMailer.notify(subject, message)
  end
end
