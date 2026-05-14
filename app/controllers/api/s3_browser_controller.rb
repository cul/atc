# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Naming/AccessorMethodName

class Api::S3BrowserController < Api::BaseController
  before_action :authorize_s3_browser_api_read_access!,
                only: %i[get_buckets get_contents_at_prefix_level get_object_details]

  def get_buckets
    render json: { buckets: buckets }
  end

  # GET /api/bucket/:bucketName/?prefix={objectPrefix}
  # Uses ListObjectV2 with a '/' delimiter to get contents at the given prefix level within the given bucket
  # Note:
  #   - The API returns the parent folder as part of the objects list, so we filter it out before returning the response
  #   - If no prefix query param is provided, this endpoint will return the top level contents of the bucket
  #   - The prefix query param should end with a '/' to be properly recognized as a folder prefix. The code will
  #     normalize any provided prefix to ensure it ends with a '/'. Conversely, it must not start with a '/'. The
  #     exception to this is a root-level search, which must be entirely empty.
  def get_contents_at_prefix_level
    bucket = params[:bucket]
    validate_bucket! bucket
    prefix = params[:prefix]
    # normalize input
    prefix += '/' unless prefix.end_with? '/'
    prefix = prefix.delete_prefix('/')
    folders = []
    objects = []

    s3_client.list_objects_v2({
      bucket: bucket,
      prefix: prefix,
      delimiter: '/'
    }).each do |response|
      response.common_prefixes.each do |s3_folder|
        folders.push(s3_folder.prefix)
      end
      response.contents.each do |s3_object|
        objects.push({
          key: s3_object.key,
          lastModified: s3_object.last_modified,
          size: s3_object.size,
          storageClass: s3_object.storage_class
        })
      end
    end

    # Filter out the matching folder itself
    objects = objects.reject do |obj|
      obj[:key] == prefix && obj[:size].zero?
    end

    render json: { folders: folders, objects: objects }
  end

  # GET /api/object/:bucketName/?key={objectKey}
  # Get object details with HeadObject
  # Note:
  #   - The key should not begin with a leading '/', and it will be normalized if included
  #   - Though the documentation for the sdk warns that any spaces must be converted to '%20' in the key, doing so will
  #     actually result in a 404. The key should be passed as-is.
  def get_object_details
    bucket = params[:bucket]
    validate_bucket! bucket
    object_key = params[:key]
    # normalize input
    object_key = object_key.delete_prefix('/')

    s3_object = s3_client.head_object({
      bucket: bucket,
      key: object_key
    })

    render json: object_details_json(bucket, object_key, s3_object)
  end

  private

  def buckets
    @buckets ||= AWS_CONFIG[:s3_browser][:buckets]
  end

  def s3_client
    @s3_client ||= S3_CLIENT
  end

  def validate_bucket!(bucket)
    return if buckets.map(&:name).include? bucket

    raise Exceptions::InvalidBucketError, "invalid bucket: #{bucket}"
  end

  def object_details_json(bucket, key, s3_object)
    {
      bucket: bucket,
      key: key,
      lastModified: s3_object.last_modified,
      size: s3_object.content_length,
      contentType: s3_object.content_type,
      storageClass: s3_object.storage_class,
      archiveStatus: s3_object.archive_status,
      restoreStatus: s3_object.restore
    }
  end

  def authorize_s3_browser_api_read_access!
    authorize_action_and_scope! Ability::ACCESS_API_READ_METHODS
  end
end
