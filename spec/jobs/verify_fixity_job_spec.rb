# frozen_string_literal: true

require 'rails_helper'

describe VerifyFixityJob do
  subject(:verify_fixity_job) { described_class.new }

  let(:aws_storage_provider) { FactoryBot.create(:storage_provider, container_name: 'AWS bucket', storage_type: 0) }
  let(:gcp_storage_provider) { FactoryBot.create(:storage_provider, container_name: 'GCP bucket', storage_type: 1) }
  let(:gcp_stored_object) { FactoryBot.create(:stored_object, storage_provider: gcp_storage_provider) }
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
  let(:aws_error_json_response) do
    '{"type": "fixity_check_error",
      "data": { "error_message": "Ooops!",
                "job_identifier": 1234,
                "bucket_name": "cul_bucket",
                "object_path": "/I/Am/An/Object",
                "checksum_algorithm_name": "SHA31415"} }'
  end

  describe '#process_aws_fixity_checksum_response' do
    let(:json_response) do
      '{"type": "fixity_check_complete",
        "data": { "checksum_hexdigest": "ABCDEF12345", "object_size": 1234 } }'
    end

    it 'returns checksum, object size, and nil for the error message if check complete' do
      result = verify_fixity_job.process_aws_fixity_checksum_response(JSON.parse(json_response))
      expect(result).to eq(['ABCDEF12345', 1234, nil])
    end

    it 'returns error message and nil for the checksum if error occured' do
      result = verify_fixity_job.process_aws_fixity_checksum_response(JSON.parse(aws_error_json_response))
      expect(result).to eq([nil, 'Ooops!'])
    end
  end

  describe '#aws_fixity_verification_record_error_message' do
    it 'returns error message to insert into FixityVerification.error_message' do
      result = verify_fixity_job.aws_fixity_verification_record_error_message(JSON.parse(aws_error_json_response))
      expect(result).to eq('Finish implementation')
    end
  end

  describe '#perform' do
    it 'calls #aws_verify_fixity if storage provider is AWS' do
      # verify_fixity_job.perform(stored_object.id)
      expect(verify_fixity_job).to receive(:aws_verify_fixity)
      verify_fixity_job.perform(aws_stored_object.id)
    end

    it 'calls #gcp_verify_fixity if storage provider is GCP' do
      # verify_fixity_job.perform(stored_object.id)
      expect(verify_fixity_job).to receive(:gcp_verify_fixity)
      verify_fixity_job.perform(gcp_stored_object.id)
    end
  end
end
