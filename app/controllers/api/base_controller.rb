# frozen_string_literal: true

class Api::BaseController < ApplicationController
  before_action :transform_json_params
  before_action :authenticate_user!

  # Handle JSON parsing errors
  rescue_from JSON::ParserError do |_exception|
    render json: { error: 'Invalid JSON in request body' }, status: :bad_request
  end

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
end
