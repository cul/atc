# frozen_string_literal: true

require 'rails_helper'

describe VerifyFixityJob do
  subject(:verify_fixity_job) { described_class.new }

  let(:aws_storage_provider) { FactoryBot.create(:storage_provider, container_name: 'AWS bucket', storage_type: 0) }
  let(:aws_stored_object) { FactoryBot.create(:stored_object, storage_provider: aws_storage_provider) }
  let(:gcp_storage_provider) { FactoryBot.create(:storage_provider, container_name: 'GCP bucket', storage_type: 1) }
  let(:gcp_stored_object) { FactoryBot.create(:stored_object, storage_provider: gcp_storage_provider) }

  describe '#process_aws_fixity_checksum_response' do
    let(:json_response) { '{"type": "fixity_check_complete", "data": { "checksum_hexdigest": "ABCDEF12345" } }' }
    let(:error_json_response) { '{"type": "fixity_check_error", "data": { "error_message": "Ooops!" } }' }

    it 'returns checksum and nil for the error message if check complete' do
      result = verify_fixity_job.process_aws_fixity_checksum_response(JSON.parse(json_response))
      expect(result).to eq(['ABCDEF12345', nil])
    end

    it 'returns error message and nil for the checksum if error occured' do
      result = verify_fixity_job.process_aws_fixity_checksum_response(JSON.parse(error_json_response))
      expect(result).to eq([nil, 'Ooops!'])
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
