# frozen_string_literal: true

require 'csv'

# Builds the CSV file for a CsvExport record
class PrepareCsvExportJob < ApplicationJob # rubocop:disable Metrics/ClassLength
  queue_as Atc::Queues::CSV_EXPORT

  CSV_HEADERS = [
    'S3 URI', 'File name', 'Modification date',
    'Storage tier', 'Size', 'Size in bytes', 'Restore in progress'
  ].freeze

  def perform(csv_export_id)
    @errors = []
    @csv_export = CsvExport.find(csv_export_id)

    @csv_export.update!(status: :processing)

    selections = JSON.parse(@csv_export.export_paths, symbolize_names: true)
    puts "Selections for CSV export #{csv_export_id}: #{selections.inspect}"
    objects = collect_objects(selections)

    csv_export_filename = write_csv_export(csv_export_id, objects)

    @csv_export.update!(status: @errors.any? ? :completed_with_errors : :success,
                        path_to_csv_file: csv_export_filename, export_errors: @errors)
  rescue StandardError => e
    Rails.logger.error("CSV export #{csv_export_id} failed: #{e.class} -> #{e.message}")
    @csv_export&.update(status: :failure, export_errors: @errors + [e.message])
  end

  private

  def write_csv_export(csv_export_id, objects)
    filename = "csv_export_#{csv_export_id}_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
    path = File.join(AWS_CONFIG[:s3_browser][:csv_exports_directory], filename)
    write_csv(path, objects)
    filename
  end

  # Ported from the S3BrowserController#collect_objects method
  def s3_client
    @s3_client ||= S3_CLIENT
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def collect_objects(selections)
    objects = []

    selections.each do |selection|
      bucket = selection[:bucket]

      # Objects under the given prefixes (folders). Listing using list_objects_v2 returns
      # everything except archive/restore status so we only fetch the extra head_object
      # on the objects that can actually have those values (see needs_storage_details?).
      selection[:prefixes].each do |prefix|
        list_prefix(bucket, prefix) do |obj|
          modify_with_storage_data(bucket, obj) if needs_storage_details?(obj)
          objects << obj
        end
      rescue Aws::S3::Errors::ServiceError => e
        @errors << "Could not read folder s3://#{bucket}/#{prefix} - #{e.message}"
      end

      # Keys represent specific files. head_meta already issues a head_object and returns the complete
      # metadata (including archive/restore status) so no additional call is needed for these.
      # puts "Processing keys: #{selection[:keys].inspect}"
      selection[:keys].each do |key|
        objects << head_meta(bucket, key)
      rescue Aws::S3::Errors::ServiceError => e
        @errors << "Could not read file s3://#{bucket}/#{key} - #{e.message}"
      end
      # puts "Objects after processing keys: #{objects.inspect}"
    end
    puts "Objects collected for CSV export: #{objects.inspect}"
    objects
  end

  # Objects in the STANDARD storage class will never have a restore in progress
  # and don't have an archive status.
  def needs_storage_details?(obj)
    obj[:storage_class] == 'INTELLIGENT_TIERING'
  end

  def modify_with_storage_data(bucket, obj)
    h = s3_client.head_object(bucket: bucket, key: obj[:key])
    obj[:archive_status] = h.archive_status
    obj[:restore]        = h.restore
  rescue Aws::S3::Errors::ServiceError => e
    @errors << "Could not read file s3://#{bucket}/#{obj[:key]} - #{e.message}"
  end

  # Like list but without delimeter
  def list_prefix(bucket, prefix)
    s3_client.list_objects_v2(bucket: bucket, prefix: prefix).each do |page|
      page.contents.each do |obj|
        next if obj.key.end_with?('/') # 0-byte folder markers, not files

        # NOTE: This object includes restore_status but that value is always nil, unless we include
        # "optional_object_attributes" in the request. Since we need to retrieve addition information using
        # head_object anyway, we retrieve the restore_status there instead of this method.
        puts obj.inspect

        yield(bucket: bucket, key: obj.key, size: obj.size, last_modified: obj.last_modified,
              storage_class: obj.storage_class, archive_status: nil, restore: nil)
      end
    end
  end

  def head_meta(bucket, key)
    h = s3_client.head_object(bucket: bucket, key: key)
    { bucket: bucket, key: key, size: h.content_length, last_modified: h.last_modified,
      storage_class: h.storage_class, archive_status: h.archive_status, restore: h.restore }
  end

  def write_csv(path, objects)
    puts "Writing CSV to #{path} with #{objects.size} objects"

    CSV.open(path, 'w') do |csv|
      csv << CSV_HEADERS
      objects.each { |obj| csv << build_row(obj) }
    end
  end

  def build_row(obj)
    row = [
      "s3://#{obj[:bucket]}/#{obj[:key]}",
      File.basename(obj[:key]),
      obj[:last_modified],
      storage_tier(obj),
      ActiveSupport::NumberHelper.number_to_human_size(obj[:size]),
      obj[:size],
      restore_in_progress?(obj[:restore])
    ]
    puts "Row for object #{obj[:key]}: #{row.inspect}"

    row
  end

  # TODO: Rewrite, probably using switch
  def storage_tier(obj)
    'STANDARD' if obj[:storage_class].nil?

    return unless obj[:storage_class] == 'INTELLIGENT_TIERING'

    if obj[:archive_status] == 'ARCHIVE_ACCESS'
      'Intelligent Tiering (Archive Access)'
    elsif obj[:archive_status] == 'DEEP_ARCHIVE_ACCESS'
      'Intelligent Tiering (Deep Archive Access)'
    else
      'Intelligent Tiering (Frequent Access, Infrequent Access, or Archive Instant Access tier)'
    end
  end

  def restore_in_progress?(restore)
    restore&.include?('ongoing-request="true"') || false
  end
end
