# frozen_string_literal: true

# Parses and validates the environment variables passed to the atc:smb rake tasks:
# bundle exec rake atc:smb:run source=L:/existing-dir/subdir repository_name="RBML" collection_name="David Byrne Papers"
class Atc::Stabilization::TaskArgs
  SOURCE_REGEX = %r{\A(?<drive>[A-Za-z]:)[\\/](?<path>.+)\z}

  SOURCE_EXAMPLE = 'source=L:/existing-dir/subdir'
  REPOSITORY_NAME_EXAMPLE = 'repository_name="RBML"'
  COLLECTION_NAME_EXAMPLE = 'collection_name="David Byrne Papers"'

  # - drive is the drive configured as the source in smb.yml (eg. 'L')
  # - source_path is the path on that drive in "/existing-dir/subdir" format
  # - repository_name is the name of the repository (eg. "RBML")
  # - collection_name is the name of the collection within the repository (eg. "David Byrne Papers")
  # - bag_name is the name of the bag assembled from the repository name, collection name and current date located
  #   at the root of the stabilization bucket
  attr_reader :drive, :source_path, :repository_name, :collection_name, :bag_name

  def self.from_env(env = ENV)
    Atc::Stabilization::TaskArgs.new(
      source: env['source'],
      repository_name: env['repository_name'],
      collection_name: env['collection_name']
    )
  end

  def initialize(source:, repository_name:, collection_name:)
    @drive, @source_path = parse_source(source)
    @repository_name = parse_name(repository_name)
    @collection_name = parse_name(collection_name)
    @bag_name = assemble_bag_name
  end

  private

  def assemble_bag_name
    normalized_repository_name = Atc::Utils::ObjectKeyNameUtils.remediate_key_name(@repository_name)
    normalized_collection_name = Atc::Utils::ObjectKeyNameUtils.remediate_key_name(@collection_name)
    current_date = Time.current.strftime('%Y%m%d_%H%M%S')

    "#{normalized_repository_name}_#{normalized_collection_name}_#{current_date}"
  end

  # TODO: Fix validation for repository_name and collection_name
  def parse_name(name)
    raise ArgumentError, "Missing required argument: #{name}" if name.blank?
    name
  end

  # Splits "L:/dir/subdir" into its two components: the source drive and a "/dir/subdir" path
  def parse_source(source)
    raise ArgumentError, "Missing required argument: #{SOURCE_EXAMPLE}" if source.blank?

    match = SOURCE_REGEX.match(source)
    raise ArgumentError, invalid_source_message(source) if match.nil?

    [parse_drive(match[:drive]), parse_source_path(match[:path], source)]
  end

  def parse_drive(drive)
    normalized_drive = normalize_drive(drive)
    return normalized_drive if normalized_drive == normalize_drive(Atc::Smb::Connector.drive)

    raise ArgumentError, "Unknown source: #{drive.upcase}"
  end

  # Converts the path portion of the source argument to a leading-slash "/existing-dir/subdir" form
  def parse_source_path(path, source)
    segments = path_segments(path.tr('\\', '/'))
    raise ArgumentError, invalid_source_message(source) if segments.empty?

    "/#{segments.join('/')}"
  end

  # Splits on slashes, dropping empty segments and rejecting anything that could escape the given path
  def path_segments(path)
    segments = path.split('/').reject(&:blank?)
    raise ArgumentError, "Invalid path: #{path.inspect}. It cannot contain '..' segments" if segments.include?('..')

    segments
  end

  def normalize_drive(drive)
    drive.to_s.upcase.delete_suffix(':')
  end

  def invalid_source_message(source)
    "Invalid source: #{source.inspect}. Expected a drive letter followed by a path, e.g. #{SOURCE_EXAMPLE}"
  end
end
