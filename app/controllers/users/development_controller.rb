# frozen_string_literal: true

class Users::DevelopmentController < Devise::SessionsController
  # Log in with a development account instead of the default CAS login.
  # Used only in the development environment, as a convenience.
  def sign_in_developer_admin
    return unless Rails.env.development?

    unless user_signed_in?
      dev_user = User.find_by(
        uid: DEVELOPMENT_ADMIN_USER_CONFIG[:uid]
      ) || User.create!(DEVELOPMENT_ADMIN_USER_CONFIG)

      sign_in(dev_user, scope: :user)
    end

    redirect_to root_path
  end

  def sign_in_development_user
    return unless Rails.env.development?

    unless user_signed_in?
      dev_user = User.find_by(
        uid: DEVELOPMENT_NON_ADMIN_USER_CONFIG[:uid]
      ) || User.create!(DEVELOPMENT_NON_ADMIN_USER_CONFIG)

      sign_in(dev_user, scope: :user)
    end

    redirect_to root_path
  end
end
