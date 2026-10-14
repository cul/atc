# frozen_string_literal: true

require 'bagit'

class Atc::Bag::Validator
  # Tag files that BagIt::Bag doesn't check. It writes its own bagit.txt when one is missing
  # and it skips tag file validation entirely when there is no tagmanifest to check against
  REQUIRED_TAG_FILES = ['bagit.txt', 'tagmanifest-sha256.txt'].freeze

  attr_reader :bag_dir

  def initialize(bag_dir)
    @bag_dir = bag_dir
  end

  def valid?
    errors.empty?
  end

  def errors
    @errors ||= collect_errors
  end

  private

  def collect_errors
    missing = check_for_missing_files
    return [missing] if missing

    bag = BagIt::Bag.new(@bag_dir)
    return [] if bag.valid?

    bag.errors.full_messages
  end

  def check_for_missing_files
    return "#{@bag_dir} does not exist" unless Dir.exist?(@bag_dir)

    missing = REQUIRED_TAG_FILES.reject { |tag_file| File.exist?(File.join(@bag_dir, tag_file)) }
    return nil if missing.empty?

    "#{@bag_dir} is missing required tag file(s): #{missing.join(', ')}"
  end
end
