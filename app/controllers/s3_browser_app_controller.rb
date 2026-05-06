# frozen_string_literal: true

class S3BrowserAppController < ApplicationController
  layout 's3_browser'
  before_action :authenticate_user!

  def index; end
end
