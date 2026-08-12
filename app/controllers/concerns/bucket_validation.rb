# frozen_string_literal: true

module BucketValidation
  extend ActiveSupport::Concern

  def buckets
    @buckets ||= AWS_CONFIG[:s3_browser][:buckets]
  end

  def validate_bucket!(bucket)
    return if buckets.map(&:name).include? bucket

    raise Atc::Exceptions::InvalidBucketError, "Invalid bucket: #{bucket}"
  end
end
