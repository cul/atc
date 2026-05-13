# frozen_string_literal: true

# rubocop:disable RSpec/AnyInstance

require 'rails_helper'

def read_buckets_from_config_file
  AWS_CONFIG[:s3_browser][:buckets]
end

describe Api::S3BrowserController, type: :request, focus: true do
  include_examples 'unauthenticated user accessing authenticated API endpoint' do
    let(:http_request) { get '/api/buckets' }
    let(:user) { FactoryBot.create(:user) }
  end

  # Useful to define some of our data upfront so it can be shared
  let(:test_s3_error_context) do
    Seahorse::Client::RequestContext.new({
      http_response: Seahorse::Client::Http::Response.new({ status_code: 500 })
    })
  end
  let(:test_s3_error) do
    Aws::S3::Errors::ServiceError.new(test_s3_error_context, 'Test error')
  end
  let(:test_bucket) { read_buckets_from_config_file.first.bucket }

  before do
    sign_in FactoryBot.create(:user)
  end

  describe '#get_buckets' do
    let(:test_buckets) do
      { buckets: read_buckets_from_config_file }.to_json
    end

    before do
      # allow_any_instance_of(described_class).to receive(:buckets).and_return(JSON.parse(test_buckets))
      get '/api/buckets'
    end

    it 'returns OK status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns a list of buckets' do
      expect(JSON.parse(response.body)).to eq(JSON.parse(test_buckets))
    end
  end

  describe '#get_contents_at_prefix_level' do
    context 'with valid bucket' do
      let(:test_prefix) { 'test-prefix/' }
      let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
      let(:expected_response) do
        {
          folders: ['test-prefix/subdir1/', 'test-prefix/subdir2/'],
          objects: [
            {
              key: 'test-prefix/object1.txt',
              lastModified: '2026-01-01T05:00:00.000Z',
              size: 2048,
              storageClass: 'STANDARD'
            },
            {
              key: 'test-prefix/object2.txt',
              lastModified: '2026-01-02T05:00:00.000Z',
              size: 4096,
              storageClass: 'STANDARD'
            }
          ]
        }
      end

      before do
        allow_any_instance_of(described_class).to receive(:s3_client).and_return(s3_client)
        s3_client.stub_responses(:list_objects_v2, {
          contents: [
            {
              key: 'test-prefix/object1.txt',
              last_modified: Time.zone.parse('2026-01-01'),
              size: 2048,
              storage_class: 'STANDARD'
            },
            {
              key: 'test-prefix/object2.txt',
              last_modified: Time.zone.parse('2026-01-02'),
              size: 4096,
              storage_class: 'STANDARD'
            }
          ],
          common_prefixes: [
            { prefix: 'test-prefix/subdir1/' },
            { prefix: 'test-prefix/subdir2/' }
          ]
        })
        get "/api/bucket/#{test_bucket}/?prefix=#{test_prefix}"
      end

      it 'returns OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'has contents of the bucket at the given prefix' do
        expect(JSON.parse(response.body, symbolize_names: true)).to eq(expected_response)
      end

      context 'when S3 client raises an error' do
        before do
          allow(s3_client).to receive(:list_objects_v2).and_raise(test_s3_error)
          get "/api/bucket/#{test_bucket}/?prefix=#{test_prefix}"
        end

        it 'returns expected error status' do
          expect(response).to have_http_status(:internal_server_error)
        end

        it 'returns the error message in the response body' do
          expect(JSON.parse(response.body)).to include('error')
        end
      end
    end

    context 'with invalid bucket' do
      before do
        get '/api/bucket/invalid-bucket/?prefix=test-prefix/'
      end

      it 'returns bad request status' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns an error message in the response body' do
        expect(JSON.parse(response.body)).to include('error')
      end
    end
  end

  describe '#get_object_details' do
    context 'with valid bucket' do
      let(:test_object_key) { 'test-prefix/object1.txt' }
      let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
      let(:expected_response) do
        {
          bucket: test_bucket,
          key: test_object_key,
          lastModified: '2026-01-01T05:00:00.000+00:00',
          size: 2048,
          storageClass: 'STANDARD',
          contentType: 'text/plain',
          archiveStatus: nil,
          restoreStatus: nil
        }
      end

      before do
        allow_any_instance_of(described_class).to receive(:s3_client).and_return(s3_client)
        s3_client.stub_responses(:head_object, {
          last_modified: Time.zone.parse('2026-01-01'),
          content_length: 2048,
          storage_class: 'STANDARD',
          content_type: 'text/plain'
        })
        get "/api/object/#{test_bucket}/?key=#{test_object_key}"
      end

      it 'returns OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'has details of the object at the given key' do
        expect(JSON.parse(response.body, symbolize_names: true)).to eq(expected_response)
      end

      context 'when S3 client raises an error' do
        before do
          allow(s3_client).to receive(:head_object).and_raise(test_s3_error)
          get "/api/object/#{test_bucket}/?key=#{test_object_key}"
        end

        it 'returns expected error status' do
          expect(response).to have_http_status(:internal_server_error)
        end

        it 'returns the error message in the response body' do
          expect(JSON.parse(response.body)).to include('error')
        end
      end
    end

    context 'with invalid bucket' do
      before do
        get '/api/object/invalid-bucket/?key=test-object-key'
      end

      it 'returns bad request status' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns an error message in the response body' do
        expect(JSON.parse(response.body)).to include('error')
      end
    end
  end
end
