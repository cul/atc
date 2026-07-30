# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize,Metrics/MethodLength

class Api::S3BrowserController < Api::BaseController
  before_action :authorize_s3_browser_api_read_access!

  def index_buckets
    render json: { buckets: buckets }
  end

  # GET /api/buckets/:bucket/list?prefix={objectPrefix}
  # Uses AWS S3 ListObjectV2 API method with a '/' delimiter to get contents at the given prefix level
  # within the given bucket.
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
    prefix = prefix.sub(%r{^/}, '') # An empty string prefix value is OK.
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
    selections.each { |selection| validate_bucket!(selection[:bucket]) }

    csv_export = CsvExport.create!(
      path_to_csv_file: "#{SecureRandom.uuid}.csv", # temp
      export_paths: selections.to_json,
      user: current_user,
      status: :pending
    )

    PrepareCsvExportJob.perform_later(csv_export.id)

    render json: { id: csv_export.id }, status: :accepted
  end

  # GET /api/buckets/:bucket/object?key={objectKey}
  # Uses AWS S3 HeadObject API method to get object details.
  # Note:
  #   - S3 object keys can technically begin with a slash, but this is a pattern that we avoid in our buckets.
  #   So any key received by this action will be normalized to remove the leading slash.
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

  def index_csv_exports
    authorize! :index, CsvExport

    csv_exports = CsvExport.accessible_by(current_ability)
                           .order(updated_at: :desc)
                           .page(params[:page])
                           .per(20)

    render json: {
      csvExports: csv_exports.map { |csv_export| csv_export_summary_json(csv_export) },
      pagination: pagination_data(csv_exports)
    }
  end

  # TODO: Add a method to camelize the response keys
  def show_csv_export
    csv_export = CsvExport.find(params[:id])
    authorize! :show, csv_export
    render json: csv_export_detail_json(csv_export)
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

    raise Atc::Exceptions::InvalidBucketError, "Invalid bucket: #{bucket}"
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

  def csv_export_detail_json(csv_export)
    {
      id: csv_export.id,
      export_paths: JSON.parse(csv_export.export_paths), # do we want to limit the number of paths returned here?
      status: csv_export.status,
      updated_at: csv_export.updated_at
    }
  end

  def csv_export_summary_json(csv_export)
    {
      id: csv_export.id,
      status: csv_export.status,
      export_paths: JSON.parse(csv_export.export_paths),
      export_errors: csv_export.export_errors,
      path_to_csv_file: csv_export.path_to_csv_file,
      updated_at: csv_export.updated_at
    }
  end

  def pagination_data(scope)
    {
      current_page: scope.current_page,
      per_page: scope.limit_value,
      total_pages: scope.total_pages,
      total_count: scope.total_count
    }
  end

  def authorize_s3_browser_api_read_access!
    authorize_action_and_scope! Ability::ACCESS_API_READ_METHODS
  end
end
