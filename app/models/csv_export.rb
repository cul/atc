# frozen_string_literal: true

class CsvExport < ApplicationRecord
  belongs_to :user
  serialize :export_errors, type: Array, coder: JSON

  enum :status, { pending: 0, processing: 1, success: 2, failure: 3 }
end
