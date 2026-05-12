# frozen_string_literal: true

class Api::UsersController < Api::BaseController
  # GET /api/users/_self
  def _self
    authorize_action_and_scope! Ability::ACCESS_S3_BROWSER_API_READ_METHODS
    render json: {
      email: current_user.email,
      uid: current_user.uid
    }
  end
end
