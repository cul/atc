# frozen_string_literal: true

class Api::S3BrowserController < Api::BaseController
  before_action :authorize_s3_browser_api_read_access!,
                only: %i[buckets get_contents_at_prefix_level get_object_details]

  def buckets
    buckets = AWS_CONFIG[:s3_browser][:buckets]
    render json: { buckets: buckets }
  end

  # GET /api/bucket/:bucketName/?prefix={objectPrefix}?continuation_token={continuationToken}
  def get_contents_at_prefix_level # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Naming/AccessorMethodName
    bucket = params[:bucket]
    unless valid_bucket? bucket
      render json: { error: 'the given bucket does not exist or is not accessible from the S3 Browser App' },
             status: :bad_request
      return
    end
    prefix = params[:prefix]
    folders = []
    objects = []

    # TODO: handle err responses https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Errors.html
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
  rescue Aws::S3::Errors::ServiceError => e
    render_aws_api_error(e)
  end

  # GET /api/object/:bucketName/?key={objectKey}
  def get_object_details # rubocop:disable Naming/AccessorMethodName
    bucket = params[:bucket]
    object_key = params[:key]
    object_key.sub!('/', '') if object_key.chr == '/' # remove leading '/' if present
    object_key.gsub!(' ', '%20') # replace any spaces with %20 encoding

    # TODO: handle err responses https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Errors.html
    s3_object = s3_client.head_object({
      bucket: bucket,
      key: object_key
    })

    render json: object_details_json(bucket, object_key, s3_object)
  rescue Aws::S3::Errors::ServiceError => e
    render_aws_api_error(e)
  end

  private

  def s3_client
    @s3_client ||= S3_CLIENT
  end

  def valid_bucket?(bucket)
    AWS_CONFIG[:s3_browser][:buckets].map(&:bucket).include? bucket
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
    render json: { response_code: err.context.http_response.status_code, error_message: err.code },
           status: err.context.http_response.status_code
  end

  def authorize_s3_browser_api_read_access!
    authorize_action_and_scope! Ability::ACCESS_API_READ_METHODS
  end
end
