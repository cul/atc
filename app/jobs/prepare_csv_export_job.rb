# frozen_string_literal: true

require 'csv'

# Builds the CSV file for a CsvExport record
class PrepareCsvExportJob < ApplicationJob
  queue_as Atc::Queues::CSV_EXPORT

  CSV_HEADERS = [
    'S3 URI', 'File name', 'Modification date',
    'Storage tier', 'Size', 'Size in bytes', 'Restore in progress'
  ].freeze

  def perform(csv_export_id)
    csv_export = CsvExport.find(csv_export_id)

    csv_export.update!(status: :processing)

    selections = JSON.parse(csv_export.export_paths, symbolize_names: true)
    puts "Selections for CSV export #{csv_export_id}: #{selections.inspect}"
    objects = collect_objects(selections)

    # TODO: Write CSV
    csv_export_path = Rails.root.join('tmp', 'csv_exports', csv_export.path_to_csv_file)
    write_csv(csv_export_path, objects)

    csv_export.update!(status: :success)
  rescue StandardError => e
    Rails.logger.error("CSV export #{csv_export_id} failed: #{e.class} -> #{e.message}")
    csv_export&.update(status: :failure, export_errors: [e.message])
  end

  private

  # Ported from the S3BrowserController#collect_objects method
  def s3_client
    @s3_client ||= S3_CLIENT
  end

  def collect_objects(selections)
    objects = []

    selections.each do |selection|
      bucket = selection[:bucket]

      # Get all objects under the given prefixes (folders)
      selection[:prefixes].each do |prefix|
        list_prefix(bucket, prefix) do |obj|
          objects << obj
        end
      end

      # Keys represent specific files so we need to get their metadata using head_object
      if selection[:keys].any?
        # puts "Processing keys: #{selection[:keys].inspect}"
        selection[:keys].each { |key| objects << head_meta(bucket, key) }
        # puts "Objects after processing keys: #{objects.inspect}"
      end

      # TODO: At this point, some of the objects will already have the archive_status and restore_status
      # values (via the keys path)
      # Refactor so that we don't duplicate the head_object calls.
      objects.each { |obj| modify_with_storage_data(bucket, obj) }
    end
    puts "Objects collected for CSV export: #{objects.inspect}"
    objects
  end

  def modify_with_storage_data(bucket, obj)
    h = s3_client.head_object(bucket: bucket, key: obj[:key])
    # puts "HeadObject for #{obj[:key]}: #{h.inspect}"
    obj[:archive_status] = h.archive_status
    obj[:restore]        = h.restore
  end

  # Like list but without delimeter
  def list_prefix(bucket, prefix)
    s3_client.list_objects_v2(bucket: bucket, prefix: prefix).each do |page|
      page.contents.each do |obj|
        next if obj.key.end_with?('/') # 0-byte folder markers, not files

        # NOTE: This object includes restore_status but that value is always nil, unless we include "optional_object_attributes"
        # in the request. Since we need to retrieve addition information using head_object anyway, we retrieve
        # the restore_status there instead of this method.
        puts "#{obj.inspect}"

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
