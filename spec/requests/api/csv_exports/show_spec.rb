# frozen_string_literal: true

require 'rails_helper'

describe 'GET /api/csv_exports/:id', type: :request do
  include_examples 'unauthenticated user accessing authenticated API endpoint' do
    let(:http_request) { get '/api/csv_exports/1' }
    let(:user) { FactoryBot.create(:user) }
  end

  context 'when authenticated' do
    context 'as the owner of the export' do
      let(:user) { FactoryBot.create(:user) }
      let(:csv_export) { FactoryBot.create(:csv_export, user: user) }

      before do
        sign_in user
        get "/api/csv_exports/#{csv_export.id}"
      end

      it 'returns OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the requested export' do
        expect(JSON.parse(response.body)['id']).to eq(csv_export.id)
      end

      it 'returns the expected detail fields' do
        expect(JSON.parse(response.body).keys).to contain_exactly(
          'id', 'exportPaths', 'exportErrors', 'status', 'updatedAt'
        )
      end
    end

    context 'as a different non-admin user' do
      let(:user) { FactoryBot.create(:user) }
      let(:csv_export) { FactoryBot.create(:csv_export) }

      before do
        sign_in user
        get "/api/csv_exports/#{csv_export.id}"
      end

      it 'returns forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as an admin user' do
      let(:user) { FactoryBot.create(:user, :admin) }
      let(:csv_export) { FactoryBot.create(:csv_export) }

      before do
        sign_in user
        get "/api/csv_exports/#{csv_export.id}"
      end

      it 'returns OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the requested export regardless of owner' do
        expect(JSON.parse(response.body)['id']).to eq(csv_export.id)
      end
    end

    context 'when the export does not exist' do
      let(:user) { FactoryBot.create(:user) }

      before do
        sign_in user
        get '/api/csv_exports/0'
      end

      it 'returns not found status' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
