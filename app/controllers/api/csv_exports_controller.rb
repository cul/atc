# frozen_string_literal: true

class Api::CsvExportsController < Api::BaseController # rubocop:disable Metrics/ClassLength
  include BucketValidation

  before_action :set_csv_export, only: [:show, :download]

  # POST /api/csv_exports
  # Validates the requested buckets, records the export request and enqueues the
  # background job. Responds 202 with the new record's id so the client can later
  # redirect to the CSV detail page.
  # A single request may span multiple buckets (one `selections` entry per bucket).
  def create
    authorize! :create, CsvExport

    selections = build_selections(csv_export_params)
    validate_selections!(selections)
    validate_no_overlapping_selections!(selections)
    selections.each { |selection| validate_bucket!(selection[:bucket]) }

    csv_export = CsvExport.create!(
      export_paths: selections.to_json,
      user: current_user,
      status: :pending
    )

    PrepareCsvExportJob.perform_later(csv_export.id)

    render_camelized_json({ id: csv_export.id }, status: :accepted)
  end

  def index
    authorize! :index, CsvExport

    csv_exports = CsvExport.accessible_by(current_ability)
                           .order(updated_at: :desc)
                           .page(params[:page])
                           .per(20)

    render_camelized_json({
      csvExports: csv_exports.map { |csv_export| csv_export_summary_json(csv_export) },
      pagination: pagination_data(csv_exports)
    })
  end

  def show
    authorize! :show, @csv_export
    render_camelized_json(csv_export_detail_json(@csv_export))
  end

  def download
    authorize! :show, @csv_export

    if @csv_export.path_to_csv_file.present?
      exports_directory = AWS_CONFIG[:s3_browser][:csv_exports_directory]
      full_path = File.join(exports_directory, @csv_export.path_to_csv_file)
      send_file full_path, filename: "csv_export_#{@csv_export.id}.csv", type: 'text/csv'
    else
      render_camelized_json({ errors: { file: ['No CSV file available for this export job.'] } }, status: :not_found)
    end
  end

  private

  def csv_export_params
    params.permit(selections: [:bucket, { files: [], directories: [] }])
  end

  def set_csv_export
    @csv_export = CsvExport.find(params.require(:id))
  end

  def csv_export_detail_json(csv_export)
    {
      id: csv_export.id,
      export_paths: JSON.parse(csv_export.export_paths),
      export_errors: csv_export.export_errors,
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

  # Normalizes the per-bucket selection payload into
  # [{ bucket:, keys: [...], prefixes: [...] }, ...]
  def build_selections(permitted)
    Array(permitted[:selections]).map do |selection|
      {
        bucket: selection[:bucket],
        keys: normalize_keys(selection[:files]),
        prefixes: normalize_prefixes(selection[:directories])
      }
    end
  end

  # Files: strip leading slashes, drop blanks and remove exact duplicates
  def normalize_keys(files)
    Array(files).map { |key| key.to_s.delete_prefix('/') }.reject(&:blank?).uniq
  end

  # Folders: strip leading slashes, drop blank entries, ensure a single trailing slash and remove exact duplicates
  def normalize_prefixes(directories)
    prefixes = Array(directories).filter_map do |dir|
      prefix = dir.to_s.delete_prefix('/')
      if prefix.empty? && dir.present?
        raise Atc::Exceptions::InvalidSelectionError,
              'Exporting an entire bucket is not supported. Select specific folders or files'
      end
      next if prefix.blank?

      prefix.end_with?('/') ? prefix : "#{prefix}/"
    end
    prefixes.uniq
  end

  # A request must include at least one selection and every selection must target
  # at least one file OR directory
  def validate_selections!(selections)
    raise Atc::Exceptions::InvalidSelectionError, 'You must include at least one selection.' if selections.empty?

    return if selections.all? { |selection| selection[:keys].any? || selection[:prefixes].any? }

    raise Atc::Exceptions::InvalidSelectionError,
          'Each selection must include at least one file or directory.'
  end

  # Rejects overlapping selections. Frontend should prevent this but we validate here to ensure
  # the request is well-formed. Overlap is defined as any of the following:
  # - a file that is already covered by a selected folder
  # - a folder that is already covered by a selected folder
  def validate_no_overlapping_selections!(selections)
    selections.each do |selection|
      prefixes = selection[:prefixes]
      overlaps = (selection[:keys] + prefixes).filter_map do |item|
        folder = prefixes.find { |prefix| item != prefix && item.start_with?(prefix) }
        "#{item} (already covered by #{folder})" if folder
      end
      next if overlaps.empty?

      raise Atc::Exceptions::InvalidSelectionError,
            "Selection for bucket '#{selection[:bucket]}' includes items already covered by a " \
            "selected folder: #{overlaps.join('; ')}"
    end
  end
end
