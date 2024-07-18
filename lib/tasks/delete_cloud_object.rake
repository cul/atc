# frozen_string_literal: true

namespace :atc do
  namespace :delete_cloud_file do
    desc "Deletes the cloud file at ENV['bucket_name'] and ENV['path'] for the given ENV['provider'] ('aws' or 'gcp'). "\
         'NOTE: Only works for files, not folders.'
    task by_path: :environment do
      provider = ENV['provider']
      bucket_name = ENV['bucket_name']
      path = ENV['path']

      case provider
      when 'aws'
        s3_object = Aws::S3::Object.new(bucket_name, path, { client: S3_CLIENT })
        if s3_object.exists?
          puts Rainbow("File exists on AWS. Deleting.").yellow
          s3_object.delete
        else
          puts Rainbow("File does NOT exist on AWS. Skipping.").blue
        end

      when 'gcp'
        gcp_object = GCP_STORAGE_CLIENT.bucket(bucket_name).file(path)
        if gcp_object.present? && gcp_object.exists?
          puts Rainbow("File exists on GCP. Deleting.").yellow
          gcp_object.delete
        else
          puts Rainbow("File does NOT exist on GCP. Skipping.").blue
        end
      else
        puts "Unknown provider: #{provider}"
      end
    end
  end
end
