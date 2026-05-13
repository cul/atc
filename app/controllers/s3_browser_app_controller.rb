# frozen_string_literal: true

class S3BrowserAppController < ApplicationController
  layout 's3_browser'
  before_action :authenticate_user!
  before_action :authorize_s3_browser_access!

  def index
    puts ''
    puts 'HIT THE INDEX ACTION'
    puts ''
  end

  private

  def authorize_s3_browser_access!
    raise CanCan::AccessDenied unless can? Ability::ACCESS_S3_BROWSER_UI, self
  end
end
