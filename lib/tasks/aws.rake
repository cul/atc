# frozen_string_literal: true

namespace :atc do
  namespace :aws do
    # Calls the S3_CLIENT#list_objects_v2 method multiple times to automatically page through all results.
    # S3_CLIENT#list_objects_v2 method returns up to 1000 results per call, and returns a token that can be
    # used in subsequent calls to get the next page of results.  This method wraps that paging functionality.
    def auto_paginating_list_object_v2(list_objects_v2_opts)
      next_continuation_token = nil

      counter = 0
      loop do
        counter += 1
        result_object = S3_CLIENT.list_objects_v2(list_objects_v2_opts.merge({
          continuation_token: next_continuation_token
        }))

        S3_CLIENT.list_objects_v2(list_objects_v2_opts).contents.each do |object|
          yield object
        end

        next_continuation_token = result_object.next_continuation_token
        break if next_continuation_token.nil?
      end
    end


    desc  'For the given bucket_name and key_prefix, iterates over objects and generates a list of their file extensions and counts'
    task list_file_extensions: :environment do
      bucket_name = ENV['bucket_name']
      key_prefix = ENV['key_prefix']

      extension_counts = {}

      auto_paginating_list_object_v2({
        bucket: bucket_name,
        prefix: key_prefix
      }) do |object|
        ext = File.extname(object.key)
        extension_counts[ext] ||= 0
        extension_counts[ext] += 1
      end

      # Sort the files by count, descending.
      extension_counts.to_a.sort_by {|pair| pair[1] }.reverse.each do |pair|
        puts "#{pair[0]}: #{pair[1]}"
      end
    end

    desc  'For the given bucket_name and key_prefix, iterates over objects in Intelligent Tiering and restores them '\
          ' if they have already transitioned to the Archive Access tier.'
    task restore_archived_objects: :environment do
      bucket_name = ENV['bucket_name']
      key_prefix = ENV['key_prefix']
      key_suffix_filter = ENV['key_suffix_filter']
      dry_run = ENV['dry_run'] == 'true'

      puts ""

      puts "This is a dry run because dry_run=true has been set.  No objects will actually be restored during this run.\n\n" if dry_run

      if key_suffix_filter.present?
        puts "Searching for objects (and filtering on objects with keys that end with \"#{key_suffix_filter}\")...\n\n"
      else
        puts "Searching for objects...\n\n"
      end
      number_of_intelligent_tiering_object_resoration_requests_submitted = 0
      number_of_intelligent_tiering_objects_with_restoration_in_progress = 0
      number_of_intelligent_tiering_objects_already_available = 0
      number_of_non_intelligent_tiering_objects_skipped = 0
      number_of_objects_skipped_based_on_key_suffix_filter = 0
      errors_encountered = []

      puts "--------------------"
      puts "Results:"
      auto_paginating_list_object_v2({
        bucket: bucket_name,
        prefix: key_prefix
      }) do |object|
        object_key = object.key
        storage_class = object.storage_class

        if storage_class == 'INTELLIGENT_TIERING'
          if key_suffix_filter.present? && !object_key.end_with?(key_suffix_filter)
            number_of_objects_skipped_based_on_key_suffix_filter += 1
            next
          end

          begin
            S3_CLIENT.restore_object({
              bucket: bucket_name,
              key: object_key,
              # For an object in Intelligent Tiering Archive Instant storage, we just pass an empty hash here.
              # No further configuration is needed.
              restore_request: {}
            }) unless dry_run
            number_of_intelligent_tiering_object_resoration_requests_submitted += 1
          rescue Aws::S3::Errors::ServiceError => e
            if e.message.include?("Restore is not allowed for the object's current storage class")
              # If we got here, that means that this object was already restored and doesn't need to be restored again
              # because it is available.  We'll silently ignore this error.
              number_of_intelligent_tiering_objects_already_available += 1
            elsif e.message.include?("Object restore is already in progress")
              # If we got here, that means that this object's restoration is already in progress and we do not need to
              # initiate another restoration request.  We'll silently ignore this error.
              number_of_intelligent_tiering_objects_with_restoration_in_progress += 1
            else
              errors_encountered << "An unexpected error occured while attempting to restore #{object_key}: #{e.message}"
            end
          end
        else
          number_of_non_intelligent_tiering_objects_skipped += 1
        end

      end

      if dry_run
        puts "Number of intelligent tiering object restoration requests that would have been made (if this wasn't a dry run): #{number_of_intelligent_tiering_object_resoration_requests_submitted}"
      else
        puts "Number of intelligent tiering object restoration requests submitted: #{number_of_intelligent_tiering_object_resoration_requests_submitted}"
        puts "Number of intelligent tiering objects with restoration in progress: #{number_of_intelligent_tiering_objects_with_restoration_in_progress}"
        puts "Number of intelligent tiering objects already available: #{number_of_intelligent_tiering_objects_already_available}"
      end
      puts "Number of objects skipped based on key_suffix_filter: #{number_of_objects_skipped_based_on_key_suffix_filter}"
      puts "Number of non intelligent tiering objects skipped: #{number_of_non_intelligent_tiering_objects_skipped}"
      puts  "\nReminder: After restoration has been initiated, it will take 3-5 hours until the files are available for download.  "\
            "The current time is #{Time.current}, so the files should be available after #{Time.current + 5.hours}."
      puts  "--------------------"
      puts "Errors: " + (errors_encountered.empty? ? 'None' : "\n#{errors_encountered.join("\n")}")

      # pids.each_with_index do |pid|
      #   print "Checking #{pid}..."
      #   dobj = DigitalObject::Base.find(pid)
      #   fobj = dobj.fedora_object
			# 	storage_object = Hyacinth::Storage.storage_object_for(fobj.datastreams['content'].dsLocation)
			# 	if storage_object.is_a?(Hyacinth::Storage::S3Object)
			# 		# NOTE: storage_object.s3_object.restore will return nil if the object has not been restored yet,
			# 		# but it will return a string if a restore operation has already been run on the object and it is
			# 		# in the process of being restored.
			# 		if storage_object.s3_object.archive_status == 'ARCHIVE_ACCESS'
			# 			if storage_object.s3_object.restore.nil?
			# 				puts "Need to restore object at: #{storage_object.location_uri}"
			# 				puts "---> Restoring archived object..."
			# 				bucket_name = storage_object.s3_object.bucket_name
			# 				key = storage_object.s3_object.key
			# 				# Make sure that bucket_name and key aren't blank.  They shouldn't ever be blank at this point in the
			# 				# code, but we want to make sure not to call restore if either of them somehow are blank.
			# 				raise if bucket_name.blank? || key.blank?

			# 				begin
			# 					restore_object_response = storage_object.s3_object.restore_object({
			# 						bucket: bucket_name,
			# 						key: key,
			# 						# For an object in Intelligent Tiering Archive Instant storage, we just pass an empty hash here.
			# 						# No further configuration is needed.
			# 						restore_request: {}
			# 					})
			# 					puts "---> Object restoration request submitted!  The object should be available within 3-5 hours."
			# 				rescue Aws::S3::Errors::ServiceError => e
			# 					puts "---> An unexpected error occurred while attempting to restore the object."
			# 				end
			# 			else
			# 				puts "---> A restore request has already been made for this object and restoration is in progress: #{storage_object.s3_object.restore}"
			# 			end
			# 		else
			# 			puts "---> Object is not currently in ARCHIVE_ACCESS state, so we will not make any changes."
			# 		end

			# 		# puts "Do we need to restore this object?"
			# 	elsif storage_object.is_a?(Hyacinth::Storage::FileObject)
			# 		puts "No need to restore this object because it's available on the local filesystem."
			# 	else
			# 		puts "Ignoring unknown object type: #{storage_object.class.name}"
			# 	end
      # end
    end

    desc 'Run a fixity check using a remote CheckPlease app deployment.'
    task fixity_check: :environment do
      bucket_name = ENV['bucket_name']
      object_path = ENV['object_path']
      checksum_algorithm_name = ENV['checksum_algorithm_name']

      job_identifier = "fixity-check-from-rake-task-#{SecureRandom.uuid}"
      remote_fixity_check = Atc::Aws::RemoteFixityCheck.new(
        CHECK_PLEASE['http_base_url'], CHECK_PLEASE['ws_url'], CHECK_PLEASE['auth_token']
      )
      response = remote_fixity_check.perform(
        job_identifier, bucket_name, object_path, checksum_algorithm_name,
        Atc::Aws::RemoteFixityCheck::HTTP_POLLING
      )
      puts "Response: #{response.inspect}"
    end

    desc 'Upload a file to Amazon S3.  This task only exists for transfer testing purposes.'
    task upload_file: :environment do
      if Rails.env != 'development'
        puts 'This task is just for transfer testing and should only be run in a development environment.'
        next
      end

      local_file_path = ENV['local_file_path']
      bucket_name = ENV['bucket_name']
      overwrite = ENV['overwrite'] == 'true'

      if local_file_path.present?
        unless File.exist?(local_file_path)
          puts Rainbow("Could not find file at local_file_path: #{local_file_path}").red
          next
        end
      else
        puts Rainbow('Missing required argument: local_file_path').red
        next
      end

      puts "Calculating sha256 checksum for #{local_file_path} ..."
      sha256_hexdigest = Digest::SHA256.file(local_file_path).hexdigest
      puts "sha256 checksum is: #{sha256_hexdigest}"

      # TODO: Decide what we want this key to be.  Right now, it just uploads the file
      # at the top level of the bucket and retains its original name.  It's easy to change
      # though, and we could potentially make it a rake task argument.
      target_object_key = File.basename(local_file_path)

      s3_uploader = Atc::Aws::S3Uploader.new(S3_CLIENT, bucket_name)
      s3_uploader.upload_file(
        local_file_path,
        target_object_key,
        :auto,
        overwrite: overwrite,
        verbose: true,
        metadata: {
          'checksum-sha256-hex': sha256_hexdigest,
          'original-path-b64' => Base64.strict_encode64(target_object_key)
        }
      )
    end
  end
end
