# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/MethodLength
# rubocop:disable Naming/MethodParameterName
# rubocop:disable Metrics/PerceivedComplexity

class Atc::Aws::RemoteFixityCheck
  STALLED_FIXITY_CHECK_JOB_TIMEOUT = 10.seconds
  POLLING_DELAY = 2.seconds
  MAX_WAIT_TIME_FOR_POLLING_JOB_START = 1.hour
  WEBSOCKET = 'websocket'
  HTTP = 'http'
  HTTP_POLLING = 'http_polling'

  def initialize(http_base_url, ws_url, auth_token)
    @http_base_url = http_base_url
    @ws_url = ws_url
    @auth_token = auth_token
  end

  def http_client
    @http_client ||= ::Faraday.new(url: @http_base_url, request: { timeout: CHECK_PLEASE['http_timeout'] }) do |f|
      f.request :authorization, 'Bearer', @auth_token
      f.response :json # decode response bodies as JSON
      f.response :raise_error # raise 4xx and 5xx responses as errors
      f.adapter :net_http # Use the Net::HTTP adapter
    end
  end

  # Returns a new websocket connection.
  # @yield [Faye::WebSocket::Client] A new websocket client instance.
  def create_websocket_connection
    Faye::WebSocket::Client.new(@ws_url, nil, { headers: { 'Authorization' => "Bearer: #{@auth_token}" } })
  end

  # Establishes a websocket connection, initiates a fixity check, and blocks until
  # the fixity check completes (or raises an exception if something unexpected happens).
  # @return [Hash] A fixity check response.
  def perform(job_identifier, bucket_name, object_path, checksum_algorithm_name, method = WEBSOCKET)
    case method
    when WEBSOCKET
      perform_websocket(job_identifier, bucket_name, object_path, checksum_algorithm_name)['data']
    when HTTP
      perform_http(bucket_name, object_path, checksum_algorithm_name)
    when HTTP_POLLING
      perform_http_polling(bucket_name, object_path, checksum_algorithm_name)
    else
      raise ArgumentError, "Unsupported perform method: #{method}"
    end
  end

  def perform_http(bucket_name, object_path, checksum_algorithm_name)
    payload = {
      'fixity_check' => {
        'bucket_name' => bucket_name,
        'object_path' => object_path,
        'checksum_algorithm_name' => checksum_algorithm_name
      }
    }.to_json
    response = http_client.post('/fixity_checks/run_fixity_check_for_s3_object', payload) do |request|
      request.headers['Content-Type'] = 'application/json'
    end

    JSON.parse(response.body)
  rescue StandardError => e
    {
      'checksum_hexdigest' => nil, 'object_size' => nil,
      'error_message' => "An unexpected error occurred: #{e.class.name} -> #{e.message}"
    }
  end

  def perform_http_polling(bucket_name, object_path, checksum_algorithm_name)
    start_time = Time.current
    payload = {
      'fixity_check' => {
        'bucket_name' => bucket_name,
        'object_path' => object_path,
        'checksum_algorithm_name' => checksum_algorithm_name
      }
    }.to_json

    fixity_check_create_response = http_client.post('/fixity_checks', payload) { |request|
      request.headers['Content-Type'] = 'application/json'
    }.body

    if fixity_check_create_response['error_message'].present?
      # Raise any unexpected error message.  It will be handled elsewhere.
      raise Atc::Exceptions::AtcError,
            fixity_check_create_response['error_message']
    end

    # If we got here, that means that the fixity check request was created successfully.
    # Now we'll poll and wait for it to complete.
    last_progress_update_time = nil
    fixity_check_response = nil
    loop do
      sleep POLLING_DELAY
      fixity_check_response = http_client.get("/fixity_checks/#{fixity_check_create_response['id']}") { |request|
        request.headers['Content-Type'] = 'application/json'
      }.body
      status = fixity_check_response['status']

      break if ['success', 'error'].include?(status)

      # If we receive a pending status, we're waiting for a background job to start processing our request.
      # Ideally this won't be for too long, since we expect there to be at least as manay CheckPlease background
      # workers as there are ATC fixity check request workers, but we'll add a timeout here just in case anything
      # is ever incorrectly configured, just so that this job doesn't ever hang indefinitely.
      if status == 'pending'
        next if Time.current - start_time < MAX_WAIT_TIME_FOR_POLLING_JOB_START

        raise Atc::Exceptions::PollingWaitTimeoutError,
              'Polling wait time has exceeded MAX_WAIT_TIME_FOR_POLLING_JOB_START '\
              "(#{MAX_WAIT_TIME_FOR_POLLING_JOB_START} seconds)"
      end

      # If we got here, that means that the job is in progress.  Let's account for the
      # possibility of the job timing out, if something goes wrong on the CheckPlease app side.

      last_progress_update_time = Time.zone.parse(fixity_check_response['updated_at'])
      if job_unresponsive?(last_progress_update_time)
        raise Atc::Exceptions::RemoteFixityCheckTimeout,
              'Timed out while waiting for a response.'
      end
    end
    fixity_check_response
  rescue StandardError => e
    {
      'checksum_hexdigest' => nil, 'object_size' => nil,
      'error_message' => "An unexpected error occurred: #{e.class.name} -> #{e.message}"
    }
  end

  def perform_websocket(job_identifier, bucket_name, object_path, checksum_algorithm_name)
    job_response = nil
    time_of_last_progress_update_message = Time.current

    EM.run do
      ws = create_websocket_connection

      # Exit the event loop when the websocket connection is closed
      ws.on(:close) { |_event| EventMachine.stop_event_loop }

      # Handle websocket messages
      ws.on(:message) do |event|
        data = JSON.parse(event.data)
        if welcome_message?(data)
          send_channel_subscription_message(ws, job_identifier)
        elsif confirm_subscription_message?(data, job_identifier)
          send_run_fixity_check_for_s3_object_message(
            ws, job_identifier, bucket_name, object_path, checksum_algorithm_name
          )
        elsif progress_message?(data, job_identifier)
          time_of_last_progress_update_message = Time.current
        elsif fixity_check_complete_or_error_message?(data, job_identifier)
          job_response = JSON.parse(data['message'])
        end
      end

      # Periodically check to see if processing is done or if it has become unresponsive
      EventMachine.add_periodic_timer(1) do
        ws.close if !job_response.nil? || job_unresponsive?(time_of_last_progress_update_message)
      end
    end

    raise Atc::Exceptions::RemoteFixityCheckTimeout, 'Timed out while waiting for a response.' if job_response.nil?

    job_response
  end

  def job_unresponsive?(last_in_progress_message_time)
    Time.current - last_in_progress_message_time > STALLED_FIXITY_CHECK_JOB_TIMEOUT
  end

  def send_channel_subscription_message(ws, job_identifier)
    ws.send(
      {
        'command': 'subscribe',
        'identifier': { 'channel': 'FixityCheckChannel', 'job_identifier': job_identifier }.to_json
      }.to_json
    )
  end

  def send_run_fixity_check_for_s3_object_message(ws, job_identifier, bucket_name, object_path, checksum_algorithm_name)
    ws.send(
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
  end

  def welcome_message?(data)
    data['type'] == 'welcome'
  end

  def confirm_subscription_message?(data, job_identifier)
    return false if data['identifier'].nil?

    data['type'] == 'confirm_subscription' && JSON.parse(data['identifier'])&.fetch('job_identifier') == job_identifier
  end

  def custom_message?(data, job_identifier)
    return false unless data['type'].nil?
    return false if data['message'].nil?
    return false if data['identifier'].nil?

    JSON.parse(data['identifier'])&.fetch('job_identifier') == job_identifier
  end

  def progress_message?(data, job_identifier)
    return false unless custom_message?(data, job_identifier)

    message_type = JSON.parse(data['message'])['type']
    message_type == 'fixity_check_in_progress'
  end

  def fixity_check_complete_or_error_message?(data, job_identifier)
    return false unless custom_message?(data, job_identifier)

    message_type = JSON.parse(data['message'])['type']
    ['fixity_check_complete', 'fixity_check_error'].include?(message_type)
  end
end
