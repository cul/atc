# frozen_string_literal: true

require 'rails_helper'

describe Atc::Aws::RemoteFixityCheck do
  let(:mock_websocket) {
    ws = double(Faye::WebSocket::Client)
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
    allow(ws).to receive(:close) { ws.trigger(:close, ->(){}) }
    ws
  }
  let(:remote_fixity_check) {
    described_class.new('ws://fake-websocket-url', 'fake-auth-token')
  }
  let(:job_identifier) { 'job-12345' }
  let(:bucket_name) { 'example-bucket' }
  let(:object_path) { 'path/to/object.tiff' }
  let(:checksum_algorithm_name) { 'sha256' }
  let(:example_job_response) { {'a' => 'b'}.to_json }

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
      expect(remote_fixity_check).to receive(:create_websocket_connection).and_return(mock_websocket)

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

  describe "#job_unresponsive?" do
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


end
