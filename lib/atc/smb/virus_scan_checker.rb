# frozen_string_literal: true

class Atc::Smb::VirusScanChecker
  POLL_INTERVAL = 10.seconds
  MAX_WAIT = 30.minutes # TBD

  def initialize(bucket_name, s3_client = S3_CLIENT)
    @bucket_name = bucket_name
    @s3_client = s3_client
  end

  def scan_status(object_key)
    response = @s3_client.get_object_tagging(bucket: @bucket_name, key: object_key)
    response.tag_set.find { |tag| tag.key == 'GuardDutyMalwareScanStatus' }&.value
  end

  def each_scan_result(object_keys)
    pending = Set.new(object_keys)
    stop_time = Time.current + MAX_WAIT

    while pending.any? && Time.current < stop_time
      # Iterating over a copy because pending is modified inside the loop
      pending.to_a.each do |object_key|
        status = scan_status(object_key)
        next if status.nil?

        pending.delete(object_key)
        yield object_key, status
      end

      sleep(POLL_INTERVAL) if pending.any?
    end

    pending.to_a
  end
end
