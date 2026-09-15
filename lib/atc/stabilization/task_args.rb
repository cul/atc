# frozen_string_literal: true

# Parses and validates the environment variables passed to the atc:stabilization rake tasks:
# bundle exec rake atc:stabilization:run source_type=ldrive source_path="/existing-dir/subdir" repository_name="RBML" collection_name="David Byrne Papers"
class Atc::Stabilization::TaskArgs
  # The sources that can be passed as source_type (see the sources section of stabilization.yml)
  SOURCE_TYPES = %w[ldrive googledrive].freeze

  # Source types that are currently supported
  IMPLEMENTED_SOURCE_TYPES = %w[ldrive].freeze

  SOURCE_TYPE_EXAMPLE = 'source_type=ldrive'
  SOURCE_PATH_EXAMPLE = 'source_path="/existing-dir/subdir"'
  REPOSITORY_NAME_EXAMPLE = 'repository_name="RBML"'
  COLLECTION_NAME_EXAMPLE = 'collection_name="David Byrne Papers"'

  # - source_type is the source configured in stabilization.yml (eg. 'ldrive')
  # - source_path is the path on that source in "/existing-dir/subdir" format
  # - repository_name is the name of the repository (eg. "RBML")
  # - collection_name is the name of the collection within the repository (eg. "David Byrne Papers")
  # - bag_name is the name of the bag assembled from the repository name, collection name and current date located
  #   at the root of the stabilization bucket
  attr_reader :source_type, :source_path, :repository_name, :collection_name, :bag_name

  def self.from_env(env = ENV)
    Atc::Stabilization::TaskArgs.new(
      source_type: env['source_type'],
      source_path: env['source_path'],
      repository_name: env['repository_name'],
      collection_name: env['collection_name']
    )
  end

  def initialize(source_type:, source_path:, repository_name:, collection_name:)
    @source_type = parse_source_type(source_type)
    raise_unimplemented_source_type_error! unless IMPLEMENTED_SOURCE_TYPES.include?(self.source_type)

    @source_path = parse_source_path(source_path)
    @repository_name = parse_name(repository_name, REPOSITORY_NAME_EXAMPLE)
    @collection_name = parse_name(collection_name, COLLECTION_NAME_EXAMPLE)
    @bag_name = assemble_bag_name
  end

  def raise_unimplemented_source_type_error!
    raise NotImplementedError, "Stabilization source_type #{self.source_type} is not implemented yet."
  end

  private

  def assemble_bag_name
    normalized_repository_name = Atc::Utils::ObjectKeyNameUtils.remediate_key_name(@repository_name)
    normalized_collection_name = Atc::Utils::ObjectKeyNameUtils.remediate_key_name(@collection_name)
    current_date = Time.current.strftime('%Y%m%d_%H%M%S')

    "#{normalized_repository_name}_#{normalized_collection_name}_#{current_date}"
  end

  def parse_name(name, example)
    raise ArgumentError, "Missing required argument: #{example}" if name.blank?
    name
  end

  # Converts source_path to a leading-slash "/existing-dir/subdir" form
  def parse_source_path(source_path)
    raise ArgumentError, "Missing required argument: #{SOURCE_PATH_EXAMPLE}" if source_path.blank?

    segments = path_segments(source_path.tr('\\', '/'))
    raise ArgumentError, invalid_source_path_message(source_path) if segments.empty?

    "/#{segments.join('/')}"
  end

  def parse_source_type(source_type)
    raise ArgumentError, "Missing required argument: #{SOURCE_TYPE_EXAMPLE}" if source_type.blank?

    normalized_source_type = source_type.strip.downcase
    return normalized_source_type if SOURCE_TYPES.include?(normalized_source_type)

    raise ArgumentError, "Unknown source_type: #{source_type.inspect}. Expected one of: #{SOURCE_TYPES.join(', ')}"
  end

  # Splits on slashes, dropping empty segments and rejecting anything that could escape the given path
  def path_segments(path)
    segments = path.split('/').reject(&:blank?)
    raise ArgumentError, "Invalid path: #{path.inspect}. It cannot contain '..' segments" if segments.include?('..')

    segments
  end

  def invalid_source_path_message(source_path)
    "Invalid source_path: #{source_path.inspect}. Expected a path on the source, e.g. #{SOURCE_PATH_EXAMPLE}"
  end
end
