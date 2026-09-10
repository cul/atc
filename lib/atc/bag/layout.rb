# frozen_string_literal: true

# Knows where files live inside a BagIt bag
class Atc::Bag::Layout
  PAYLOAD_DIRECTORY = 'data'

  # The prefix the whole bag lives under within its bucket (eg. 'folder1-folder2')
  attr_reader :bag_root_prefix

  def initialize(bag_root_prefix)
    @bag_root_prefix = bag_root_prefix
  end

  # The bag-relative path of a payload file (eg. 'data/subdir/file.txt'). Used by the payload manifest
  # so it leaves out the bag root on purpose.
  def payload_path(normalized_path)
    File.join(PAYLOAD_DIRECTORY, normalized_path)
  end

  # Where a payload file lives within the bucket (eg. folder1-folder2/data/subdir/file.txt)
  def payload_object_key(normalized_path)
    object_key(payload_path(normalized_path))
  end

  # Where a tag file lives within the bucket (eg. 'folder1-folder2/bag-info.txt')
  def tag_file_object_key(tag_file)
    object_key(File.basename(tag_file))
  end

  private

  def object_key(*segments)
    [@bag_root_prefix, *segments].join('/')
  end
end
