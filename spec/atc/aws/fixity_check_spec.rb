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

  describe '#fixity_checksum_object_size' do
    let(:remote_fixity_check) do
      dbl = instance_double(Atc::Aws::RemoteFixityCheck)
      allow(dbl).to receive(:perform).and_return(remote_fixity_check_perform_response)
      dbl
    end

    before do
      allow(Atc::Aws::RemoteFixityCheck).to receive(:new).and_return(remote_fixity_check)
    end

    context 'with a response without errors' do
      let(:remote_fixity_check_perform_response) do
        {
          'checksum_hexdigest' => 'ABCDEF12345',
          'object_size' => 1234
        }
      end

      it 'returns the object checksum and object size, and nil for the error message' do
        result = aws_fixity_check.fixity_checksum_object_size
        expect(result).to eq(
          [
            remote_fixity_check_perform_response['checksum_hexdigest'],
            remote_fixity_check_perform_response['object_size'],
            nil
          ]
        )
      end
    end

    context 'with a response with errors' do
      let(:remote_fixity_check_perform_response) do
        {
          'error_message' => 'Ooops!'
        }
      end

      it 'returns nil for the object checksum and object size' do
        result = aws_fixity_check.fixity_checksum_object_size
        expect(result[0]).to eq nil
        expect(result[1]).to eq nil
      end

      it 'returns the error message' do
        result = aws_fixity_check.fixity_checksum_object_size
        expect(result[2]).to eq(remote_fixity_check_perform_response['error_message'])
      end
    end
  end
end
