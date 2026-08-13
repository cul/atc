# frozen_string_literal: true

class CsvExport < ApplicationRecord
  belongs_to :user
  serialize :export_errors, type: Array, coder: JSON

  enum :status, { pending: 0, processing: 1, success: 2, failure: 3, completed_with_errors: 4 }

  after_destroy :remove_csv_file

  private

  def remove_csv_file
    return if path_to_csv_file.blank?

    FileUtils.rm_f(File.join(AWS_CONFIG[:s3_browser][:csv_exports_directory], path_to_csv_file))
  end
end
