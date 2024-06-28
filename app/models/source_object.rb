# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/PerceivedComplexity
# rubocop:disable Metrics/MethodLength

class SourceObject < ApplicationRecord
  include PathHashes

  belongs_to :repository, optional: true
  belongs_to :fixity_checksum_algorithm, class_name: 'ChecksumAlgorithm', optional: true
  has_many :pending_transfers, inverse_of: :source_object, dependent: :destroy

  validates :path, :path_hash, presence: { strict: true }
  validates :object_size, presence: true
  # Some db backends don't enforce a limit on binary field length,
  # so the limit below is meant to ensure that we don't ever
  # accidentally add a larger value. Make sure to update this
  # value if the database limit ever changes.
  validates :fixity_checksum_value, length: { maximum: 64 }

  validates_with PathValidator, on: :update
  validates_with PathHashValidator
  validates_with FixityChecksumValidator

  def self.for_path(local_file_path)
    path_hash = Digest::SHA256.digest(local_file_path)
    self.find_by(path_hash: path_hash)
  end

  # Returns the storage providers for the associated source_path, based on the atc.yml config
  # @return [Array<StorageProvider>] An array of storage providers.
  def storage_providers_for_source_path
    @storage_providers_for_source_path ||= begin
      storage_providers = []
      ATC[:source_paths_to_storage_providers]&.each do |path_prefix, config|
        next unless self.path.start_with?(path_prefix.to_s)

        config[:storage_providers]&.each do |storage_provider_config|
          storage_provider = StorageProvider.find_by(
            storage_type: StorageProvider.storage_types[storage_provider_config[:storage_type]],
            container_name: storage_provider_config[:container_name]
          )
          storage_providers << storage_provider unless storage_provider.nil?
        end
      end
      # If this method is being called, we expect there to be a storage provider for this source_object's path.
      # So if no storage_providers were found, raise an exception.
      if storage_providers.empty?
        raise Atc::Exceptions::StorageProviderMappingNotFound,
              'Could not find an atc.yml storage provider that maps to the path '\
              "for SourceObject #{self.id} (path = #{self.path})"
      end

      storage_providers
    end
  end
end
