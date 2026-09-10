# frozen_string_literal: true

# Parses and validates the environment variables passed to the atc:smb rake tasks:
# bundle exec rake atc:smb:run source=L:/existing-dir/subdir ingest_bucket_target=path/within/bucket
# TODO: Add "overwrite" arg
class Atc::Stabilization::TaskArgs
  SOURCE_REGEX = %r{\A(?<drive>[A-Za-z]:)[\\/](?<path>.+)\z}

  SOURCE_EXAMPLE = 'source=L:/existing-dir/subdir'
  INGEST_BUCKET_TARGET_EXAMPLE = 'ingest_bucket_target=folder1/folder2'

  # - drive is a key in the sources section of smb.yml (eg. 'L')
  # - source_path is the path on that drive in "/existing-dir/subdir" format
  # - ingest_path is the ingest bucket target path ("folder1/folder2")
  # - stabilization_path is the hyphenated form of that target, used at the root of the stabilization
  #   bucket ("folder1-folder2")
  attr_reader :drive, :source_path, :ingest_path, :stabilization_path

  # TODO: overwrite flag
  def self.from_env(env = ENV)
    Atc::Stabilization::TaskArgs.new(
      source: env['source'],
      ingest_bucket_target: env['ingest_bucket_target']
    )
  end

  def initialize(source:, ingest_bucket_target:)
    @drive, @source_path = parse_source(source)
    segments = parse_ingest_bucket_target(ingest_bucket_target)
    @ingest_path = segments.join('/')
    @stabilization_path = segments.join('-')
  end

  # The host, share and credentials configured for this source's drive
  def source_config
    configured_sources[@drive]
  end

  private

  # Splits "L:/dir/subdir" into its two components: the source drive and a "/dir/subdir" path
  def parse_source(source)
    raise ArgumentError, "Missing required argument: #{SOURCE_EXAMPLE}" if source.blank?

    match = SOURCE_REGEX.match(source)
    raise ArgumentError, invalid_source_message(source) if match.nil?

    [parse_drive(match[:drive]), parse_source_path(match[:path], source)]
  end

  def parse_drive(drive)
    normalized_drive = normalize_drive(drive)
    return normalized_drive if configured_sources.key?(normalized_drive)

    raise ArgumentError, "Unknown source: #{drive.upcase}"
  end

  # Converts the path portion of the source argument to a leading-slash "/existing-dir/subdir" form
  def parse_source_path(path, source)
    segments = path_segments(path.tr('\\', '/'))
    raise ArgumentError, invalid_source_message(source) if segments.empty?

    "/#{segments.join('/')}"
  end

  # Splits a path relative to the ingest bucket into the segments that both destination paths are built from
  def parse_ingest_bucket_target(target)
    raise ArgumentError, "Missing required argument: #{INGEST_BUCKET_TARGET_EXAMPLE}" if target.blank?

    segments = path_segments(target)
    raise ArgumentError, invalid_target_message(target) unless valid_target?(segments)

    segments
  end

  # Every segment has to be usable as part of an object key
  def valid_target?(segments)
    segments.any? && Atc::Utils::ObjectKeyNameUtils.valid_key_name?(segments.join('/'))
  end

  # Splits on slashes, dropping empty segments and rejecting anything that could escape the given path
  def path_segments(path)
    segments = path.split('/').reject(&:blank?)
    raise ArgumentError, "Invalid path: #{path.inspect}. It cannot contain '..' segments" if segments.include?('..')

    segments
  end

  # The sources section of smb.yml, keyed by source
  def configured_sources
    @configured_sources ||= (SMB_CONFIG[:sources] || {}).transform_keys { |drive| normalize_drive(drive) }
  end

  def normalize_drive(drive)
    drive.to_s.upcase.delete_suffix(':')
  end

  def invalid_source_message(source)
    "Invalid source: #{source.inspect}. Expected a drive letter followed by a path, e.g. #{SOURCE_EXAMPLE}"
  end

  def invalid_target_message(target)
    "Invalid ingest_bucket_target: #{target.inspect}. Expected a path within the ingest bucket containing only " \
      "letters, numbers and the characters - _ . ( ), e.g. #{INGEST_BUCKET_TARGET_EXAMPLE}"
  end
end
