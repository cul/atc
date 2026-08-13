# frozen_string_literal: true

# Deletes CsvExport records (and their CSV files) older than the retention period
class Atc::CsvExports::ExpiredPurger
  RETENTION_PERIOD = 6.months

  def call
    cutoff = RETENTION_PERIOD.ago
    Rails.logger.info("Deleting CsvExports created before #{cutoff.iso8601}")

    counts = { deleted: 0, failed: 0 }
    CsvExport.where('created_at < ?', cutoff).find_each do |csv_export|
      delete_expired(csv_export)
      counts[:deleted] += 1
    rescue StandardError => e
      counts[:failed] += 1
      Rails.logger.error("Failed to delete CsvExport id=#{csv_export.id}: #{e.message}")
    end

    Rails.logger.info("Delete complete: #{counts[:deleted]} deleted, #{counts[:failed]} failed")
    counts
  end

  private

  def delete_expired(csv_export)
    file = csv_export.path_to_csv_file.presence || 'none'
    created_at = csv_export.created_at.iso8601
    csv_export.destroy!
    Rails.logger.info("Deleted CsvExport id=#{csv_export.id} created_at=#{created_at} file=#{file}")
  end
end
