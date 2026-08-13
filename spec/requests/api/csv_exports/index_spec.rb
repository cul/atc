# frozen_string_literal: true

require 'rails_helper'

describe 'GET /api/csv_exports', type: :request do
  include_examples 'unauthenticated user accessing authenticated API endpoint' do
    let(:http_request) { get '/api/csv_exports' }
    let(:user) { FactoryBot.create(:user) }
  end

  context 'when authenticated' do
    let(:returned_export_ids) { JSON.parse(response.body)['csvExports'].pluck('id') }

    context 'as a non-admin user' do
      let(:user) { FactoryBot.create(:user) }
      let!(:own_export) { FactoryBot.create(:csv_export, user: user) }
      let!(:other_export) { FactoryBot.create(:csv_export) }

      before do
        sign_in user
        get '/api/csv_exports'
      end

      it 'returns OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'includes exports owned by the current user' do
        expect(returned_export_ids).to include(own_export.id)
      end

      it 'excludes exports owned by other users' do
        expect(returned_export_ids).not_to include(other_export.id)
      end

      it 'returns each export with the expected summary fields' do
        summary = JSON.parse(response.body)['csvExports'].first
        expect(summary.keys).to contain_exactly(
          'id', 'status', 'exportPaths', 'exportErrors', 'pathToCsvFile', 'updatedAt'
        )
      end

      it 'includes pagination metadata scoped to their exports' do
        pagination = JSON.parse(response.body)['pagination']
        expect(pagination).to include(
          'currentPage' => 1, 'perPage' => 20, 'totalPages' => 1, 'totalCount' => 1
        )
      end
    end

    context 'as an admin user' do
      let(:user) { FactoryBot.create(:user, :admin) }
      let!(:own_export) { FactoryBot.create(:csv_export, user: user) }
      let!(:other_export) { FactoryBot.create(:csv_export) }

      before do
        sign_in user
        get '/api/csv_exports'
      end

      it 'returns OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns exports belonging to every user' do
        expect(returned_export_ids).to contain_exactly(own_export.id, other_export.id)
      end
    end

    context 'without any exports' do
      let(:user) { FactoryBot.create(:user) }

      before do
        sign_in user
        get '/api/csv_exports'
      end

      it 'returns OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns an empty list of exports' do
        expect(JSON.parse(response.body)['csvExports']).to eq([])
      end
    end
  end
end
