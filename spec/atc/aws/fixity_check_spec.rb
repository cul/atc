# frozen_string_literal: true

require 'rails_helper'

describe Atc::Aws::FixityCheck do
  subject(:aws_fixity_check) { described_class.new(aws_stored_object, 3141) }

  let(:aws_storage_provider) { FactoryBot.create(:storage_provider, container_name: 'AWS bucket', storage_type: 0) }
  let(:checksum_algorithm) { FactoryBot.create(:checksum_algorithm, name: 'SHA31415', empty_binary_value: 0) }
  let(:source_object) do
    FactoryBot.create(:source_object,
                      fixity_checksum_algorithm: checksum_algorithm,
                      fixity_checksum_value: 'ABCDEF12345',
                      object_size: 4321)
  end
  let(:aws_stored_object) do
    FactoryBot.create(:stored_object,
                      source_object: source_object,
                      storage_provider: aws_storage_provider)
  end
  let(:aws_hash_response) do
    { 'type' => 'fixity_check_complete',
      'data' => { 'checksum_hexdigest' => 'ABCDEF12345', 'object_size' => 1234 } }
  end
  let(:aws_error_hash_response) do
    { 'type' => 'fixity_check_error',
      'data' => { 'error_message' => 'Ooops!',
                  'job_identifier' => 1234,
                  'bucket_name' => 'cul_bucket',
                  'object_path' => 'I/Am/An/Object',
                  'checksum_algorithm_name' => 'SHA31415' } }
  end

  describe '#fixity_checksum_object_size' do
    context 'with an AWS response without errors ' do
      it 'returns the object checksum and object size, and nil for the aws error message' do
        allow(aws_fixity_check).to receive(:aws_fixity_websocket_channel_stream) { aws_hash_response }
        result = aws_fixity_check.fixity_checksum_object_size
        expect(result).to eq(['ABCDEF12345', 1234, nil])
      end
    end

    context 'with an AWS response with errors ' do
      it 'returns nil for the object checksum and object size' do
        allow(aws_fixity_check).to receive(:aws_fixity_websocket_channel_stream) { aws_error_hash_response }
        result = aws_fixity_check.fixity_checksum_object_size
        expect(result[0]).to eq nil
        expect(result[1]).to eq nil
      end

      it 'returns the error message (including data)' do
        allow(aws_fixity_check).to receive(:aws_fixity_websocket_channel_stream) { aws_error_hash_response }
        result = aws_fixity_check.fixity_checksum_object_size
        expect(result[2]).to include('Ooops!')
        expect(result[2]).to include('cul_bucket')
      end
    end
  end

  describe '#response_data_as_string' do
    it 'returns the aws response data info as a string' do
      result = aws_fixity_check.response_data_as_string aws_error_hash_response
      expect(result).to include('Ooops!')
      expect(result).to include('cul_bucket')
    end
  end
end
