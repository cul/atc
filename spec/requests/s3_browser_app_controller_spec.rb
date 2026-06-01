# frozen_string_literal: true

require 'rails_helper'

describe S3BrowserAppController, type: :request do
  describe 'index' do
    before do
      get '/browse'
    end

    context 'as unauthenticated user' do
      it 'responds with redirect/found status code' do
        expect(response).to have_http_status(:found)
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'as an authenticated user' do
      let(:user) { FactoryBot.create(:user) }

      before do
        sign_in user
        get '/browse'
      end

      it 'responds with OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'creates React App root element' do
        expect(response.parsed_body.to_html).to include('id="s3-browser-app"')
      end
    end
  end
end
