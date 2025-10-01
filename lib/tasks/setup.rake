# frozen_string_literal: true

namespace :atc do
  namespace :setup do
    desc 'Set up application config files'
    task :config_files do
      config_template_dir = Rails.root.join('config/templates')
      config_dir = Rails.root.join('config')
      Dir.foreach(config_template_dir) do |entry|
        next unless entry.end_with?('.yml')

        src_path = File.join(config_template_dir, entry)
        dst_path = File.join(config_dir, entry.gsub('.template', ''))
        if File.exist?(dst_path)
          puts "#{Rainbow("File already exists (skipping): #{dst_path}").blue.bright}\n"
        else
          FileUtils.cp(src_path, dst_path)
          puts Rainbow("Created file at: #{dst_path}").green
        end
      end
    end

    desc 'Set up checksum algirithm records'
    task checksum_algorithms: :environment do
      [
        { name: 'SHA256', empty_binary_value: Digest::SHA256.new.digest },
        { name: 'SHA512', empty_binary_value: Digest::SHA512.new.digest },
        { name: 'CRC32C', empty_binary_value: Digest::CRC32c.new.digest },
        # NOTE: If we add MD5 later and use it for the transfer_checksum_algorithm, we'll need to adjust the size of
        # the transfer_checksum_algorithm column becuse it currently holds a maximum of 4 bytes.
        # { name: 'MD5', empty_binary_value: Digest::MD5.new.digest }
      ].each do |checksum_algorithm_args|
        if ChecksumAlgorithm.exists?(name: checksum_algorithm_args[:name])
          puts "#{Rainbow("ChecksumAlgorithm already exists (skipping): #{checksum_algorithm_args[:name]}").blue.bright}\n"
        else
          ChecksumAlgorithm.create!(**checksum_algorithm_args)
          puts Rainbow("Created ChecksumAlgorithm: #{checksum_algorithm_args[:name]}").green
        end
      end
    end

    desc 'Set up StorageProviders'
    task storage_providers: :environment do
      storage_provider_container_name = ENV['storage_provider_container_name']
      if storage_provider_container_name.nil?
        puts 'Missing storage_provider_container_name (Example: storage_provider_container_name=some-bucket-name)'
        next
      end

      [
        { storage_type: StorageProvider.storage_types[:aws], container_name: storage_provider_container_name },
        { storage_type: StorageProvider.storage_types[:gcp], container_name: storage_provider_container_name },
      ].each do |storage_provider_args|
        if StorageProvider.exists?(**storage_provider_args)
          puts "#{Rainbow("StorageProvider already exists (skipping): #{storage_provider_args.inspect}").blue.bright}\n"
        else
          StorageProvider.create!(**storage_provider_args)
          puts Rainbow("Created StorageProvider: #{storage_provider_args.inspect}").green
        end
      end
    end

    desc 'Set up test config files'
    task test_storage_providers: :environment do
      [
        { storage_type: StorageProvider.storage_types[:aws], container_name: 'cul-dlstor-digital-testing1' },
        { storage_type: StorageProvider.storage_types[:gcp], container_name: 'cul-dlstor-digital-testing1' },
        { storage_type: StorageProvider.storage_types[:cul], container_name: '/cul/cul99' },
      ].each do |storage_provider_args|
        if StorageProvider.exists?(**storage_provider_args)
          puts "#{Rainbow("StorageProvider already exists (skipping): #{StorageProvider.storage_types.key(storage_provider_args[:storage_type])} => #{storage_provider_args[:container_name]}").blue.bright}\n"
        else
          StorageProvider.create!(**storage_provider_args)
          puts Rainbow("Created StorageProvider: #{StorageProvider.storage_types.key(storage_provider_args[:storage_type])} => #{storage_provider_args[:container_name]}").green
        end
      end
    end
  end
end
