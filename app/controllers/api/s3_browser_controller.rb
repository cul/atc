# frozen_string_literal: true

class Api::S3BrowserController < Api::BaseController
  # GET /hello
  def greeting
    render json: { greeting: 'hello!' }
  end
end
