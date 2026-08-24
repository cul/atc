# frozen_string_literal: true

require 'rails_helper'

describe 'GET /api/csv_exports/:id/download', type: :request do
  def csv_file_path(name)
    File.join(AWS_CONFIG[:s3_browser][:csv_exports_directory], name)
  end

  include_examples 'unauthenticated user accessing authenticated API endpoint' do
    let(:http_request) { get '/api/csv_exports/1/download' }
    let(:user) { FactoryBot.create(:user) }
  end

  context 'when authenticated' do
    let(:user) { FactoryBot.create(:user) }

    context 'as the owner, when the export has a generated file' do
      let(:filename) { 'download_spec_export.csv' }
      let(:file_contents) { "S3 URI,File name\ns3://test-bucket/a.txt,a.txt\n" }
      let(:csv_export) { FactoryBot.create(:csv_export, user: user, path_to_csv_file: filename) }

      before do
        FileUtils.mkdir_p(File.dirname(csv_file_path(filename)))
        File.write(csv_file_path(filename), file_contents)
        sign_in user
        get "/api/csv_exports/#{csv_export.id}/download"
      end

      after { FileUtils.rm_f(csv_file_path(filename)) }

      it 'returns OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'responds with a CSV content type' do
        expect(response.media_type).to eq('text/csv')
      end

      it 'sends the file contents' do
        expect(response.body).to eq(file_contents)
      end
    end

    context 'as the owner, when no file has been generated yet' do
      let(:csv_export) { FactoryBot.create(:csv_export, user: user, path_to_csv_file: nil) }

      before do
        sign_in user
        get "/api/csv_exports/#{csv_export.id}/download"
      end

      it 'returns not found status' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns a file error in the response body' do
        expect(JSON.parse(response.body)['errors']).to have_key('file')
      end
    end

    context 'as a different non-admin user' do
      let(:csv_export) { FactoryBot.create(:csv_export) }

      before do
        sign_in user
        get "/api/csv_exports/#{csv_export.id}/download"
      end

      it 'returns forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
