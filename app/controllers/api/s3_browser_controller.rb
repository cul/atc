# frozen_string_literal: true

class Api::S3BrowserController < Api::BaseController
  # GET /hello
  def greeting
    render json: { greeting: 'hello!' }
  end

  def buckets
    buckets = AWS_CONFIG[:s3_browser][:buckets]
    render json: { buckets: buckets }
  end

  # GET /api/bucket/:bucketName/?prefix={objectPrefix}?continuation_token={continuationToken}
  def contents_at_prefix_level
    # check for included :continuation_token from URL params
    # take :prefix from URL params
    # call list_objects_v2
    #   use :prefix
    #   use :delimiter = '/'
    #   use :continuation_token if present
    # include in response:
    #   content (objects)
    #   commonPrefixes (folders at this level)
    #   isTruncated (if pageable)
    #   nextContinuationToken (for subsequent requests)
  end
end
