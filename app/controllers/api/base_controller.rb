# frozen_string_literal: true

class Api::BaseController < ApplicationController
  before_action :transform_json_params

  # Handle JSON parsing errors
  rescue_from JSON::ParserError, with: :handle_json_parse_error
  rescue_from Atc::Exceptions::InvalidBucketError, with: :handle_invalid_bucket_error
  rescue_from Atc::Exceptions::InvalidKeyName, with: :handle_invalid_key_name_error
  rescue_from Atc::Exceptions::InvalidSelectionError, with: :handle_invalid_selection_error
  rescue_from Aws::S3::Errors::ServiceError, with: :handle_aws_service_error

  private

  def authorize_action_and_scope!(action, scope = self)
    raise CanCan::AccessDenied unless can? action, scope
  end

  # Convert incoming JSON request body keys from camelCase to snake_case
  def transform_json_params
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

  # Renders a JSON response with all keys deep-transformed to camelCase.
  # Use in place of `render json:` throughout API controllers.
  def render_camelized_json(data, **options)
    render json: deep_camelize(data), **options
  end

  # Recursively transforms all hash to lowerCamelCase
  def deep_camelize(obj)
    case obj
    when Hash
      obj.transform_keys { |k| k.to_s.camelize(:lower) }
         .transform_values { |v| deep_camelize(v) }
    when Array
      obj.map { |v| deep_camelize(v) }
    else
      obj
    end
  end

  def handle_json_parse_error(error)
    Rails.logger.error "JSON parse error: #{error.message}"
    render json: { error: 'Invalid JSON in request body' },
           status: :bad_request
  end

  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Errors.html
  def handle_aws_service_error(error)
    Rails.logger.error "AWS Error - AWS responded with HTTP code: #{error.context.http_response.status_code}."\
      " AWS Error code: #{error.code}." \
      " AWS Error message: '#{error.message}'"
    render json: { error: 'There was an error communicating with Amazon Web Services. Check the ATC logs for details' },
           status: :service_unavailable
  end

  def handle_invalid_bucket_error
    render json: { error: 'The given bucket does not exist or is not accessible from the S3 Browser App' },
           status: :bad_request
  end

  def handle_invalid_key_name_error(error)
    render json: { error: error.message },
           status: :bad_request
  end

  # The selections payload has nothing to export (no selections at all
  # or a selection with neither files nor directories)
  def handle_invalid_selection_error(error)
    render json: { error: error.message },
           status: :unprocessable_entity
  end
end
