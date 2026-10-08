# frozen_string_literal: true

require 'rails_helper'

describe Atc::Aws::VirusScanChecker do
  # Used to manipulate time so we don't have to wait on sleep()
  include ActiveSupport::Testing::TimeHelpers

  after { travel_back }

  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:bucket_name) { 'example_bucket' }
  let(:object_key) { 'example/object/key' }
  let(:virus_scan_checker) { described_class.new(bucket_name, s3_client) }

  def stub_object_tags(tags)
    s3_client.stub_responses(:get_object_tagging, { tag_set: tags })
  end

  # Stubs the GuardDuty scan status tag (nil status represents an object that has not been scanned yet).
  def stub_successive_scan_statuses(*statuses)
    s3_client.stub_responses(:get_object_tagging, lambda { |_context|
      status = statuses.shift
      { tag_set: status.nil? ? [] : [{ key: 'GuardDutyMalwareScanStatus', value: status }] }
    })
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(virus_scan_checker).to be_a(described_class)
    end
  end

  describe '#scan_status' do
    it 'returns the value of the GuardDutyMalwareScanStatus tag' do
      stub_object_tags([{ key: 'GuardDutyMalwareScanStatus', value: 'NO_THREATS_FOUND' }])
      expect(virus_scan_checker.scan_status(object_key)).to eq('NO_THREATS_FOUND')
    end

    it 'returns nil when the object has not been scanned yet' do
      stub_object_tags([{ key: 'unrelated-tag', value: 'unrelated-value' }])
      expect(virus_scan_checker.scan_status(object_key)).to be_nil
    end

    it 'returns nil when the object has no tags at all' do
      stub_object_tags([])
      expect(virus_scan_checker.scan_status(object_key)).to be_nil
    end
  end

  describe '#each_scan_result' do
    it 'yields each object key with its scan status' do
      stub_object_tags([{ key: 'GuardDutyMalwareScanStatus', value: 'NO_THREATS_FOUND' }])
      expect { |block|
        virus_scan_checker.each_scan_result(['key-1', 'key-2'], &block)
      }.to yield_successive_args(['key-1', 'NO_THREATS_FOUND'], ['key-2', 'NO_THREATS_FOUND'])
    end

    it 'returns an empty array when all of the objects have been scanned' do
      stub_object_tags([{ key: 'GuardDutyMalwareScanStatus', value: 'NO_THREATS_FOUND' }])
      expect(virus_scan_checker.each_scan_result(['key-1', 'key-2']) { |_key, _status| }).to eq([])
    end

    it 'polls again after the poll interval when an object has not been scanned yet' do
      stub_successive_scan_statuses(nil, 'NO_THREATS_FOUND')
      allow(virus_scan_checker).to receive(:sleep)
      expect { |block|
        virus_scan_checker.each_scan_result([object_key], &block)
      }.to yield_with_args(object_key, 'NO_THREATS_FOUND')
      expect(virus_scan_checker).to have_received(:sleep).with(described_class::POLL_INTERVAL).once
    end

    it 'returns the keys that are still unscanned when the maximum wait time has elapsed' do
      stub_object_tags([])
      # Advance the clock so that the poll loop reaches its time limit
      allow(virus_scan_checker).to receive(:sleep) { |seconds| travel(seconds) }
      expect { |block|
        expect(virus_scan_checker.each_scan_result([object_key], &block)).to eq([object_key])
      }.not_to yield_control
    end
  end
end
