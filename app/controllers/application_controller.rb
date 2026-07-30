# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  rescue_from CanCan::AccessDenied do |exception|
    if current_user.nil?
      redirect_to new_user_session_path
    else
      Rails.logger.error exception.inspect
      access_denied
    end
  end

  private

  def access_denied
    render file: Rails.root.join('public/403.html'), status: :forbidden, layout: false
  end
end
