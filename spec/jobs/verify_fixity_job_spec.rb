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

  describe '#perform' do
    it 'calls #aws_verify_fixity if storage provider is AWS' do
      expect(verify_fixity_job).to receive(:aws_verify_fixity)
      verify_fixity_job.perform(aws_stored_object.id)
    end

    it 'calls #gcp_verify_fixity if storage provider is GCP' do
      expect(verify_fixity_job).to receive(:gcp_verify_fixity)
      verify_fixity_job.perform(gcp_stored_object.id)
    end
  end

  describe '#create_fixity_verification_record_if_needed' do
    context 'with existing FixityVerification(s) for the given StoredObject' do
      let(:aws_fixity_verification_pending) do
        FactoryBot.create(:fixity_verification,
                          source_object: source_object,
                          stored_object: aws_stored_object,
                          status: 0)
      end

      it 'calls #process_existing_fixity_verification_record' do
        aws_fixity_verification_pending
        expect(verify_fixity_job).to receive(:process_existing_fixity_verification_record)
        verify_fixity_job.create_fixity_verification_record_if_needed(aws_stored_object)
      end
    end

    context 'without an existing FixityVerification(s) for the given StoredObject' do
      it 'calls #create_pending_fixity_verification' do
        expect(verify_fixity_job).to receive(:create_pending_fixity_verification)
        verify_fixity_job.create_fixity_verification_record_if_needed(aws_stored_object)
      end
    end
  end

  describe '#process_existing_fixity_verification_record' do
    context 'with existing FixityVerification.status failure' do
      let(:aws_fixity_verification_pending) do
        FactoryBot.create(:fixity_verification,
                          source_object: source_object,
                          stored_object: aws_stored_object,
                          status: 0)
      end

      it 'returns nil' do
        result =
          verify_fixity_job.process_existing_fixity_verification_record(aws_stored_object,
                                                                        aws_fixity_verification_pending)
        expect(result).to eq(nil)
      end
    end

    context 'with existing FixityVerification.status pending' do
      let(:aws_fixity_verification_failure) do
        FactoryBot.create(:fixity_verification,
                          source_object: source_object,
                          stored_object: aws_stored_object,
                          status: 1)
      end

      it 'calls #create_pending_fixity_verification' do
        expect(verify_fixity_job).to receive(:create_pending_fixity_verification).with(aws_stored_object)
        verify_fixity_job.process_existing_fixity_verification_record(aws_stored_object,
                                                                      aws_fixity_verification_failure)
      end
    end
  end

  describe '#create_pending_fixity_verification' do
    it 'calls #FixityVerification.create!' do
      result = verify_fixity_job.create_pending_fixity_verification(aws_stored_object)
      expect(result).to be_an_instance_of(FixityVerification)
    end
  end

  describe '#process_aws_fixity_websocket_channel_stream' do
    context 'receives a check complete from the aws fixity server' do
      let(:aws_json_response) do
        '{"type": "fixity_check_complete",
          "data": { "checksum_hexdigest": "ABCDEF12345", "object_size": 1234 } }'
      end

      it 'and returns checksum, object size, and nil for the error message' do
        allow(verify_fixity_job).to receive(:aws_fixity_websocket_channel_stream) { aws_json_response }
        result =
          verify_fixity_job.process_aws_fixity_websocket_channel_stream(aws_stored_object,
                                                                        1)
        expect(result).to eq(['ABCDEF12345', 1234, nil])
      end
    end

    context 'receives a fixity check error from the aws fixity server' do
      it 'and returns error message, and nil for the checksum and object size' do
        allow(verify_fixity_job).to receive(:aws_fixity_websocket_channel_stream) { aws_error_json_response }
        result =
          verify_fixity_job.process_aws_fixity_websocket_channel_stream(aws_stored_object,
                                                                        1)
        expect(result).to eq([nil, nil, 'Ooops!'])
      end
    end
  end

  describe '#aws_fixity_verification_record_error_message' do
    it 'returns error message to insert into FixityVerification.error_message' do
      result = verify_fixity_job.aws_fixity_verification_record_error_message(JSON.parse(aws_error_json_response))
      expect(result).to eq('Finish implementation')
    end
  end
end
