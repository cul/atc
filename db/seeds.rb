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
	name: 'SHA256', empty_value: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
)

ChecksumAlgorithm.find_or_create_by!(
	name: 'MD5', empty_value: 'd41d8cd98f00b204e9800998ecf8427e'
)

ChecksumAlgorithm.find_or_create_by!(
	name: 'CRC32C', empty_value: '00000000'
)

StorageProvider.find_or_create_by!(name: 'AWS')
StorageProvider.find_or_create_by!(name: 'GCP')
StorageProvider.find_or_create_by!(name: 'NETAPP', on_prem: true)