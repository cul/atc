# frozen_string_literal: true

# rubocop:disable RSpec/ExampleLength

require 'rails_helper'

describe Atc::Aws::RemoteFixityCheck do
  let(:mock_websocket) do
    ws = double(Faye::WebSocket::Client) # rubocop:disable RSpec/VerifiedDoubles
    # Intercept bindings to "on"
    allow(ws).to receive(:on) { |a, &block|
      procs_for_on = ws.instance_variable_get(:@procs_for_on) || {}
      procs_for_on[a] ||= []
      procs_for_on[a] << block
      ws.instance_variable_set(:@procs_for_on, procs_for_on)
    }
    # Allow manual call to "on" bindings later, via trigger_on
    allow(ws).to receive(:trigger) { |a, event|
      procs_for_on = ws.instance_variable_get(:@procs_for_on) || {}
      procs_for_on[a] ||= []
      procs_for_on[a].each { |prc| prc.call(event) }
    }
    # Allow ws.close to trigger any on(:close) procs.
    allow(ws).to receive(:close) { ws.trigger(:close, -> {}) }
    ws
  end
  let(:remote_fixity_check) { described_class.new('ws://fake-websocket-url', 'fake-auth-token') }
  let(:job_identifier) { 'job-12345' }
  let(:bucket_name) { 'example-bucket' }
  let(:object_path) { 'path/to/object.tiff' }
  let(:checksum_algorithm_name) { 'sha256' }
  let(:example_job_response) { { 'a' => 'b' }.to_json }

  let(:fixity_check_complete_message) do
    {
      'identifier' => { 'channel' => 'FixityCheckChannel', 'job_identifier' => job_identifier }.to_json,
      'message' => {
        'type' => 'fixity_check_complete',
        'data' => {
          'bucket_name' => bucket_name,
          'object_path' => object_path,
          'checksum_algorithm_name' => checksum_algorithm_name,
          'checksum_hexdigest' => Digest::SHA256.hexdigest('something'),
          'object_size' => 123
        }
      }.to_json
    }
  end

  describe '#perform' do
    it 'works as expected' do
      allow(remote_fixity_check).to receive(:create_websocket_connection).and_return(mock_websocket)

      job_response = nil
      t = Thread.new do
        job_response = remote_fixity_check.perform(job_identifier, bucket_name, object_path, checksum_algorithm_name)
      end

      # Wait a moment to allow the job in the other thread to start
      sleep 2

      # Manually trigger a message
      mock_websocket.trigger(:message, OpenStruct.new(data: fixity_check_complete_message.to_json))

      # Wait for the thread to finish
      t.join

      expect(job_response).to eq(JSON.parse(fixity_check_complete_message['message']))
    end
  end

  describe '#job_unresponsive?' do
    it 'returns true when the passed-in time is more than STALLED_FIXITY_CHECK_JOB_TIMEOUT seconds in the past' do
      expect(
        remote_fixity_check.job_unresponsive?(
          Time.current - (Atc::Aws::RemoteFixityCheck::STALLED_FIXITY_CHECK_JOB_TIMEOUT + 1)
        )
      ).to eq(true)
    end

    it 'returns false when the passed-in time is fewer than STALLED_FIXITY_CHECK_JOB_TIMEOUT seconds in the past' do
      expect(
        remote_fixity_check.job_unresponsive?(
          Time.current - (Atc::Aws::RemoteFixityCheck::STALLED_FIXITY_CHECK_JOB_TIMEOUT - 1)
        )
      ).to eq(false)
    end
  end

  describe '#send_channel_subscription_message' do
    it 'sends the expected message' do
      expect(mock_websocket).to receive(:send).with(
        {
          'command': 'subscribe',
          'identifier': { 'channel': 'FixityCheckChannel', 'job_identifier': job_identifier }.to_json
        }.to_json
      )
      remote_fixity_check.send_channel_subscription_message(mock_websocket, job_identifier)
    end
  end

  describe '#send_run_fixity_check_for_s3_object_message' do
    it 'sends the expected message' do
      expect(mock_websocket).to receive(:send).with(
        {
          'command': 'message',
          'identifier': { 'channel': 'FixityCheckChannel', 'job_identifier': job_identifier }.to_json,
          'data': {
            'action': 'run_fixity_check_for_s3_object',
            'bucket_name': bucket_name,
            'object_path': object_path,
            'checksum_algorithm_name': checksum_algorithm_name
          }.to_json
        }.to_json
      )
      remote_fixity_check.send_run_fixity_check_for_s3_object_message(
        mock_websocket,
        job_identifier,
        bucket_name,
        object_path,
        checksum_algorithm_name
      )
    end
  end

  describe '#welcome_message?' do
    let(:welcome_message) do
      { 'type' => 'welcome' }
    end
    let(:invalid_welcome_message) do
      { 'nope' => 'nope' }
    end

    it 'returns true when matching data is supplied' do
      expect(remote_fixity_check.welcome_message?(welcome_message)).to eq(true)
    end

    it 'returns false when non-matching data is supplied' do
      expect(remote_fixity_check.welcome_message?(invalid_welcome_message)).to eq(false)
    end
  end

  describe '#confirm_subscription_message?' do
    let(:confirm_subscription_message) do
      {
        'type' => 'confirm_subscription',
        'identifier' => {
          'job_identifier' => job_identifier
        }.to_json
      }
    end
    let(:invalid_confirm_subscription_message) do
      { 'nope' => 'nope' }
    end

    it 'returns true when matching data is supplied' do
      expect(
        remote_fixity_check.confirm_subscription_message?(confirm_subscription_message, job_identifier)
      ).to eq(true)
    end

    it 'returns false when non-matching data is supplied' do
      expect(
        remote_fixity_check.confirm_subscription_message?(invalid_confirm_subscription_message, job_identifier)
      ).to eq(false)
    end
  end

  context 'custom messages' do
    # fixity_check_in_progress messages are a type of custom message
    let(:progress_message) do
      {
        'identifier' => {
          'job_identifier' => job_identifier
        }.to_json,
        'message' => {
          'type' => 'fixity_check_in_progress'
        }.to_json
      }
    end
    # fixity_check_complete messages are a type of custom message
    let(:fixity_check_complete_message) do
      {
        'identifier' => {
          'job_identifier' => job_identifier
        }.to_json,
        'message' => {
          'type' => 'fixity_check_complete',
          'data' => { 'example' => 'data' }
        }.to_json
      }
    end
    # fixity_check_error messages are a type of custom message
    let(:fixity_check_error_message) do
      {
        'identifier' => {
          'job_identifier' => job_identifier
        }.to_json,
        'message' => {
          'type' => 'fixity_check_error',
          'data' => { 'example' => 'data' }
        }.to_json
      }
    end

    describe '#custom_message?' do
      it 'returns true when matching data is supplied' do
        expect(remote_fixity_check.custom_message?(progress_message, job_identifier)).to eq(true)
        expect(remote_fixity_check.custom_message?(fixity_check_complete_message, job_identifier)).to eq(true)
        expect(remote_fixity_check.custom_message?(fixity_check_error_message, job_identifier)).to eq(true)
      end

      it 'returns false when non-matching data is supplied' do
        expect(remote_fixity_check.custom_message?({ 'nope' => 'nope' }, job_identifier)).to eq(false)
      end
    end

    describe '#progress_message?' do
      it 'returns true when matching data is supplied' do
        expect(remote_fixity_check.progress_message?(progress_message, job_identifier)).to eq(true)
      end

      it 'returns false when non-matching data is supplied' do
        expect(remote_fixity_check.progress_message?(fixity_check_complete_message, job_identifier)).to eq(false)
      end
    end

    describe '#fixity_check_complete_or_error_message?' do
      it 'returns true when matching data is supplied' do
        expect(
          remote_fixity_check.fixity_check_complete_or_error_message?(fixity_check_complete_message, job_identifier)
        ).to eq(true)
        expect(
          remote_fixity_check.fixity_check_complete_or_error_message?(fixity_check_error_message, job_identifier)
        ).to eq(true)
      end

      it 'returns false when non-matching data is supplied' do
        expect(
          remote_fixity_check.fixity_check_complete_or_error_message?(progress_message, job_identifier)
        ).to eq(false)
      end
    end
  end
end
