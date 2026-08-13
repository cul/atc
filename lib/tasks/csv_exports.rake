# frozen_string_literal: true

namespace :atc do
  namespace :csv_exports do
    desc 'Delete CsvExports and their CSV files if they are older than the retention period (6 months).'
    task delete_expired: :environment do
      result = Atc::CsvExports::ExpiredPurger.new.call
      puts "CsvExport purge complete: #{result[:deleted]} deleted, #{result[:failed]} failed."
    end
  end
end
