# frozen_string_literal: true

require 'rails_helper'

describe 'POST /api/csv_exports', type: :request do
  let(:valid_bucket) { AWS_CONFIG[:s3_browser][:buckets].first[:name] }

  include_examples 'unauthenticated user accessing authenticated API endpoint' do
    let(:http_request) { post '/api/csv_exports' }
    let(:user) { FactoryBot.create(:user) }
  end

  context 'when authenticated' do
    let(:user) { FactoryBot.create(:user) }

    before do
      allow(PrepareCsvExportJob).to receive(:perform_later)
      sign_in user
    end

    def post_export(selections)
      post '/api/csv_exports', params: { selections: selections }, as: :json
    end

    context 'with a valid selection' do
      let(:selections) do
        [{ bucket: valid_bucket, files: ['general/city_records.pdf'], directories: ['dissertations/'] }]
      end

      it 'returns accepted status' do
        post_export(selections)
        expect(response).to have_http_status(:accepted)
      end

      it 'returns the id of the new export' do
        post_export(selections)
        expect(JSON.parse(response.body)['id']).to eq(CsvExport.last.id)
      end

      it 'creates a new export' do
        expect { post_export(selections) }.to change(CsvExport, :count).by(1)
      end

      it 'creates a pending export owned by the current user' do
        post_export(selections)
        expect(CsvExport.last).to have_attributes(user: user, status: 'pending')
      end

      it 'enqueues the preparation job for the new export' do
        post_export(selections)
        expect(PrepareCsvExportJob).to have_received(:perform_later).with(CsvExport.last.id)
      end
    end

    context 'with exact duplicate entries in a selection' do
      let(:selections) do
        [{ bucket: valid_bucket, files: ['a.txt', 'a.txt'], directories: ['dissertations/', 'dissertations/'] }]
      end

      it 'returns accepted status' do
        post_export(selections)
        expect(response).to have_http_status(:accepted)
      end

      it 'stores the selection with duplicates collapsed' do
        post_export(selections)
        stored = JSON.parse(CsvExport.last.export_paths).first
        expect(stored).to include('keys' => ['a.txt'], 'prefixes' => ['dissertations/'])
      end
    end

    context 'with an empty selections list' do
      it 'returns unprocessable entity status' do
        post_export([])
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with a selection that targets neither files nor directories' do
      let(:selections) { [{ bucket: valid_bucket, files: [], directories: [] }] }

      it 'returns unprocessable entity status' do
        post_export(selections)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with a file already covered by a selected folder' do
      let(:selections) do
        [{ bucket: valid_bucket, files: ['albums/img1.jpg'], directories: ['albums/'] }]
      end

      it 'returns unprocessable entity status' do
        post_export(selections)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not create an export' do
        expect { post_export(selections) }.not_to change(CsvExport, :count)
      end
    end

    context 'with an invalid bucket' do
      let(:selections) { [{ bucket: 'not-a-configured-bucket', files: ['a.txt'], directories: [] }] }

      it 'returns bad request status' do
        post_export(selections)
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
