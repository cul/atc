# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize,Metrics/MethodLength

class Api::S3BrowserController < Api::BaseController
  # before_action :authorize_s3_browser_api_read_access!,
  #               only: %i[index_buckets list object]
  skip_before_action :verify_authenticity_token

  def index_buckets
    render json: { buckets: buckets }
  end

  # GET /api/buckets/:bucket/list?prefix={objectPrefix}
  # Uses ListObjectV2 with a '/' delimiter to get contents at the given prefix level within the given bucket
  # Note:
  #   - The API returns the parent folder as part of the objects list, so we filter it out before returning the response
  #   - If no prefix query param is provided, this endpoint will return the top level contents of the bucket
  #   - The prefix query param should end with a '/' to be properly recognized as a folder prefix. The code will
  #     normalize any provided prefix to ensure it ends with a '/'. Conversely, it must not start with a '/'. The
  #     exception to this is a root-level search, which must be entirely empty.
  def list # rubocop:disable Metrics/CyclomaticComplexity
    bucket = list_params[:bucket]
    validate_bucket! bucket
    prefix = list_params[:prefix] || ''
    # normalize input
    prefix += '/' unless prefix.end_with? '/'
    prefix = prefix.delete_prefix('/') # unfortunate method name but we need to rm leading /. A blank prefix is OK.
    folders = []
    objects = []

    s3_client.list_objects_v2({
      bucket: bucket,
      prefix: prefix,
      delimiter: '/'
    }).each do |response|
      response.common_prefixes.each do |s3_folder|
        folders.push(s3_folder.prefix)
      end
      response.contents.each do |s3_object|
        objects.push({
          key: s3_object.key,
          lastModified: s3_object.last_modified,
          size: s3_object.size,
          storageClass: s3_object.storage_class
        })
      end
    end

    # Filter out the matching folder itself, if a 0-byte folder object exists for it
    objects = objects.reject do |obj|
      obj[:key] == prefix && obj[:size].zero?
    end

    render json: { folders: folders, objects: objects }
  end

  # POST /api/csv_exports
  # Validates the requested buckets, records the export request and enqueues the
  # background job. Responds 202 with the new record's id so the client can later
  # redirect to the CSV detail page.
  # A single request may span multiple buckets (one `selections` entry per bucket).
  def queue_csv_export_job
    selections = build_selections(csv_export_params)
    puts "Selections!!! for CSV export: #{selections.inspect}"
    selections.each { |selection| validate_bucket!(selection[:bucket]) }

    user_test = User.find_by(id: 1)

    csv_export = CsvExport.create!(
      path_to_csv_file: "#{SecureRandom.uuid}.csv", # temp
      export_paths: selections.to_json,
      user: user_test,
      status: :pending
    )

    PrepareCsvExportJob.perform_later(csv_export.id)

    render json: { id: csv_export.id }, status: :accepted
  end

  # TODO: Move into resque job to export to CSV
  # Should accept:
  # - bucket
  # - list of keys (files)
  # - list of prefixes (folders)
  def export_to_csv_final
    bucket = params[:bucket]
    validate_bucket!(bucket)

    # Normalize the keys and prefixes
    keys = Array(params[:files]).map { |k| k.to_s.delete_prefix('/') }
    prefixes = Array(params[:directories]).map do |dir|
      dir = dir.to_s.delete_prefix('/')
      dir.end_with?('/') ? dir : "#{dir}/"
    end

    all_objects = collect_objects(bucket, keys, prefixes)
    render json: { files: all_objects }

    # TODO: Transform the objects into a CSV format
    # rows = all_objects.map { |obj| build_row(bucket, obj) }
    # render json: { files: rows }
  end

  def collect_objects(bucket, keys, prefixes)
    objects = []

    # Get all objects under the given prefixes (folders)
    prefixes.each do |prefix|
      list_prefix(bucket, prefix) do |obj|
        objects << obj
      end
    end

    # Keys represent specific files so we need to get their metadata using head_object
    if keys.any?
      # puts "Processing keys: #{keys.inspect}"
      keys.each { |key| objects << head_meta(bucket, key) }
      # puts "Objects after processing keys: #{objects.inspect}"
    end

    # TODO: At this point, some of the objects will already have the archive_status and restore_status
    # values (via the keys path)
    # Refactor so that we don't duplicate the head_object calls.
    objects.each { |obj| modify_with_storage_data(bucket, obj) }
    objects
  end

  def modify_with_storage_data(bucket, obj)
    h = s3_client.head_object(bucket: bucket, key: obj[:key])
    # puts "HeadObject for #{obj[:key]}: #{h.inspect}"
    obj[:archive_status] = h.archive_status
    obj[:restore]        = h.restore
  end

  def head_meta(bucket, key)
    h = s3_client.head_object(bucket: bucket, key: key)
    { key: key, size: h.content_length, last_modified: h.last_modified,
      storage_class: h.storage_class, archive_status: h.archive_status, restore: h.restore }
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

        yield(key: obj.key, size: obj.size, last_modified: obj.last_modified,
              storage_class: obj.storage_class, archive_status: nil, restore: nil)
      end
    end
  end

  # GET /api/buckets/:bucket/object?key={objectKey}
  # Get object details with HeadObject
  # Note:
  #   - The key should not begin with a leading '/', and it will be normalized if included
  #   - Though the documentation for the sdk warns that any spaces must be converted to '%20' in the key, doing so will
  #     actually result in a 404. The key should be passed as-is.
  def object
    bucket = object_params[:bucket]
    validate_bucket! bucket

    object_key = object_params[:key]
    # normalize input
    object_key = object_key.delete_prefix('/')

    s3_object = s3_client.head_object({
      bucket: bucket,
      key: object_key
    })

    render json: object_details_json(bucket, object_key, s3_object)
  end

  private

  def list_params
    params.permit(:bucket, :prefix)
  end

  def object_params
    params.require(:key)
    params.permit(:bucket, :key)
  end

  def csv_export_params
    params.permit(selections: [:bucket, { files: [], directories: [] }])
  end

  # Normalizes the per-bucket selection payload into
  # [{ bucket:, keys: [...], prefixes: [...] }, ...]
  def build_selections(permitted)
    puts "In build_selections with permitted: #{permitted.inspect}"
    Array(permitted[:selections]).map do |selection|
      {
        bucket: selection[:bucket],
        keys: Array(selection[:files]).map { |key| key.to_s.delete_prefix('/') },
        prefixes: Array(selection[:directories]).map do |dir|
          dir = dir.to_s.delete_prefix('/')
          dir.end_with?('/') ? dir : "#{dir}/"
        end
      }
    end
  end

  def buckets
    @buckets ||= AWS_CONFIG[:s3_browser][:buckets]
  end

  def s3_client
    @s3_client ||= S3_CLIENT
  end

  def validate_bucket!(bucket)
    return if buckets.map(&:name).include? bucket

    raise Atc::Exceptions::InvalidBucketError, "invalid bucket: #{bucket}"
  end

  def object_details_json(bucket, key, s3_object)
    {
      bucket: bucket,
      key: key,
      lastModified: s3_object.last_modified,
      size: s3_object.content_length,
      contentType: s3_object.content_type,
      storageClass: s3_object.storage_class || 'STANDARD', # s3 api returns nil for standard storage class
      archiveStatus: s3_object.archive_status,
      restoreStatus: s3_object.restore
    }
  end

  def authorize_s3_browser_api_read_access!
    authorize_action_and_scope! Ability::ACCESS_API_READ_METHODS
  end
end
