# frozen_string_literal: true

require 'rails_helper'

describe SourceObject do
  let(:sha256_checksum_algorithm) { FactoryBot.create(:checksum_algorithm, :sha256) }
  let(:source_object) { FactoryBot.create(:source_object) }

  describe 'validations' do
    it 'has a path_hash of 32 bytes' do
      expect(source_object.path_hash.bytesize).to be 32
    end

    it 'does not permit reassignment of path' do
      expect { source_object.update!(path: 'LQSyM') }.to raise_error ActiveRecord::RecordInvalid
    end

    it 'requires a path value when saving a new object (strict validation)' do
      expect { FactoryBot.create(:source_object, path: nil).save }.to raise_error(ActiveModel::StrictValidationFailed)
    end

    it 'requires a path value when saving an existing object (strict validation)' do
      source_object.path = nil
      expect { source_object.save }.to raise_error(ActiveModel::StrictValidationFailed)
    end
  end

  describe '.for_path' do
    let(:source_object) { FactoryBot.create(:source_object) }

    it { expect(described_class.for_path(source_object.path)).to eql(source_object) }
  end

  context 'with a no-content checksum' do
    let(:source_object_with_zero_byte_size_and_empty_binary_value_checksum) do
      FactoryBot.build(
        :source_object,
        object_size: 0,
        fixity_checksum_algorithm: sha256_checksum_algorithm,
        fixity_checksum_value: sha256_checksum_algorithm.empty_binary_value
      )
    end
    let(:source_object_with_positive_byte_size_and_empty_binary_value_checksum) do
      FactoryBot.build(
        :source_object,
        object_size: 1,
        fixity_checksum_algorithm: sha256_checksum_algorithm,
        fixity_checksum_value: sha256_checksum_algorithm.empty_binary_value
      )
    end

    it 'saves without error the object size is zero' do
      expect(source_object_with_zero_byte_size_and_empty_binary_value_checksum.save).to eq(true)
    end

    it 'fails to save when object size is a positive number' do
      expect(source_object_with_positive_byte_size_and_empty_binary_value_checksum.save).to eq(false)
      expect(
        source_object_with_positive_byte_size_and_empty_binary_value_checksum.errors
      ).to include(:fixity_checksum_value)
    end
  end

  describe 'checksum values' do
    let(:content) { 'This is the content' }
    let(:sha512_checksum_algorithm) { FactoryBot.create(:checksum_algorithm, :sha512) }
    let(:sha256_content_checksum) { Digest::SHA256.digest(content) }
    let(:sha512_content_checksum) { Digest::SHA512.digest(content) }

    it 'can store a sha256 checksum value in fixity_checksum_value' do
      source_object = FactoryBot.build(
        :source_object,
        object_size: content.length,
        fixity_checksum_algorithm: sha256_checksum_algorithm,
        fixity_checksum_value: sha256_content_checksum
      )
      expect(source_object.save).to eq(true)
      source_object.reload
      expect(source_object.fixity_checksum_value.length).to eq(32)
    end

    it 'can store a sha512 checksum value in fixity_checksum_value' do
      source_object = FactoryBot.build(
        :source_object,
        object_size: content.length,
        fixity_checksum_algorithm: sha512_checksum_algorithm,
        fixity_checksum_value: sha512_content_checksum
      )
      expect(source_object.save).to eq(true)
      source_object.reload
      expect(source_object.fixity_checksum_value.length).to eq(64)
    end
  end

  describe '#storage_providers_for_source_path' do
    let(:path_prefix) { source_object.path.match(%r{/[^/]+/})[0] }
    let!(:aws_storage_provider) { FactoryBot.create(:storage_provider, :aws) }
    let!(:gcp_storage_provider) { FactoryBot.create(:storage_provider, :gcp) }

    context 'with matching source providers defined in atc.yml' do
      before do
        stub_const('ATC', ATC.merge({
          source_paths_to_storage_providers: {
            # Add a mapping for our source_object's path
            path_prefix.to_sym => {
              path_mapping: '',
              storage_providers: [
                {
                  storage_type: aws_storage_provider.storage_type,
                  container_name: aws_storage_provider.container_name
                },
                {
                  storage_type: gcp_storage_provider.storage_type,
                  container_name: gcp_storage_provider.container_name
                }
              ]
            }
          }
        }))
      end

      it 'returns the expected source providers' do
        expect(source_object.storage_providers_for_source_path).to eq([aws_storage_provider, gcp_storage_provider])
      end
    end

    context 'with NON-matching source providers defined in atc.yml' do
      before do
        stub_const('ATC', ATC.merge({
          source_paths_to_storage_providers: {
            # Add a mapping for our source_object's path
            '/path/does/not/match/': {
              path_mapping: '',
              storage_providers: [
                {
                  storage_type: aws_storage_provider.storage_type,
                  container_name: aws_storage_provider.container_name
                },
                {
                  storage_type: gcp_storage_provider.storage_type,
                  container_name: gcp_storage_provider.container_name
                }
              ]
            }
          }
        }))
      end

      it "raises an exception because this source_object's path cannot be resolved to a StorageProvider" do
        expect {
          source_object.storage_providers_for_source_path
        }.to raise_error(Atc::Exceptions::StorageProviderMappingNotFound)
      end
    end
  end
end
