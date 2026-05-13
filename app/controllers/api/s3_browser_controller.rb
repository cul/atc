# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Naming/AccessorMethodName

class Api::S3BrowserController < Api::BaseController
  rescue_from Exceptions::InvalidBucketError, with: :handle_invalid_bucket_error
  before_action :authorize_s3_browser_api_read_access!,
                only: %i[get_buckets get_contents_at_prefix_level get_object_details]

  def get_buckets
    render json: { buckets: buckets }
  end

  # GET /api/bucket/:bucketName/?prefix={objectPrefix}?continuation_token={continuationToken}
  def get_contents_at_prefix_level
    bucket = params[:bucket]
    validate_bucket! bucket
    prefix = params[:prefix]
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

    render json: { folders: folders, objects: objects }
  rescue Aws::S3::Errors::ServiceError => e # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Errors.html
    render_aws_api_error(e)
  end

  # GET /api/object/:bucketName/?key={objectKey}
  def get_object_details # rubocop:disable Naming/AccessorMethodName
    bucket = params[:bucket]
    validate_bucket! bucket
    object_key = params[:key]
    # remove leading '/' if present and replace spaces with %20 encoding
    object_key = object_key.delete_prefix('/').gsub(' ', '%20')

    s3_object = s3_client.head_object({
      bucket: bucket,
      key: object_key
    })

    render json: object_details_json(bucket, object_key, s3_object)
  rescue Aws::S3::Errors::ServiceError => e # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Errors.html
    render_aws_api_error(e)
  end

  private

  def buckets
    @buckets ||= AWS_CONFIG[:s3_browser][:buckets]
  end

  def s3_client
    @s3_client ||= S3_CLIENT
  end

  def validate_bucket!(bucket)
    return if buckets.map(&:bucket).include? bucket

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

  def render_aws_api_error(err)
    render json: { response_code: err.context.http_response.status_code, error: err.code },
           status: err.context.http_response.status_code
  end

  def authorize_s3_browser_api_read_access!
    authorize_action_and_scope! Ability::ACCESS_API_READ_METHODS
  end

  def handle_invalid_bucket_error
    render json: { error: 'The given bucket does not exist or is not accessible from the S3 Browser App' },
           status: :bad_request
  end
end
