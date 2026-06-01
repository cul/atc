# frozen_string_literal: true

# This file includes tests related to the functionality implemented in the
# Api::BaseController
# It should be included in any API controller request specs

# Shared example to check that a route requires authentication and
# authorization. When including this example a let statement must be provided
# with the http_request and user.
#
# @example Usage
#   include_examples 'authenticated API endpoint' do
#     let(:http_request) { get :index }
#     let(:user) { FactoryBot.create(:user) }
#   end
shared_examples 'unauthenticated user accessing authenticated API endpoint' do
  before do
    http_request
  end

  context 'without being logged in' do
    it 'returns unauthorized status code' do
      expect(response).to have_http_status(:unauthorized)
    end

    it 'includes error message in JSON body' do
      expect(JSON.parse(response.body)).to have_key 'error'
    end
  end
end
