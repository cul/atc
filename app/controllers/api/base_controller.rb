# frozen_string_literal: true

class Api::BaseController < ApplicationController
  before_action :transform_json_params
  before_action :authenticate_user!

  # Handle JSON parsing errors
  rescue_from JSON::ParserError, with: :handle_json_parse_error
  rescue_from Exceptions::InvalidBucketError, with: :handle_invalid_bucket_error
  rescue_from Aws::S3::Errors::ServiceError, with: :handle_aws_service_error

  private

  def authorize_action_and_scope!(action, scope = self)
    raise CanCan::AccessDenied unless can? action, scope
  end

  # Convert incoming JSON request body keys from camelCase to snake_case
  def transform_json_params # rubocop:disable Metrics/AbcSize
    return unless request.content_type&.include?('application/json')
    return unless request.body.size.positive?

    # Rewind the body stream to the beginning in case it has already been read,
    # see: https://stackoverflow.com/a/29777523
    request.body.rewind
    raw_post = request.body.read

    data = ActiveSupport::JSON.decode(raw_post)
    data = { _json: data } unless data.is_a?(Hash)

    # Recursively transform all keys from camelCase to snake_case
    data.deep_transform_keys!(&:underscore)
    params.merge!(data.with_indifferent_access)
  end

  def handle_json_parse_error(error)
    Rails.logger.error "JSON parse error: #{error.message}"
    render json: { error: 'Invalid JSON in request body' }, status: :bad_request
  end

  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Errors.html
  def handle_aws_service_error(err)
    render json: { response_code: err.context.http_response.status_code, error: err.code },
           status: err.context.http_response.status_code
  end

  def handle_invalid_bucket_error
    render json: { error: 'The given bucket does not exist or is not accessible from the S3 Browser App' },
           status: :bad_request
  end
end
