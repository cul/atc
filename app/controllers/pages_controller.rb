# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    render plain: "ATC: v#{APP_VERSION}"
  end
end
