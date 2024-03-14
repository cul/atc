# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

ChecksumAlgorithm.find_or_create_by!(
	name: 'SHA256', empty_binary_value: Digest::SHA256.new.digest
)

ChecksumAlgorithm.find_or_create_by!(
	name: 'SHA512', empty_binary_value: Digest::SHA512.new.digest
)

ChecksumAlgorithm.find_or_create_by!(
	name: 'CRC32C', empty_binary_value: Digest::CRC32c.new.digest
)

StorageProvider.find_or_create_by!(storage_type: StorageProvider.storage_types[:aws], container_name: 'cul-dlstor-digital-preservation')
StorageProvider.find_or_create_by!(storage_type: StorageProvider.storage_types[:gcp], container_name: 'cul-dlstor-digital-preservation')
StorageProvider.find_or_create_by!(storage_type: StorageProvider.storage_types[:cul], container_name: 'netapp')
