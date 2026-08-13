# frozen_string_literal: true

require 'rails_helper'

describe PrepareCsvExportJob do
  subject(:job) { described_class.new }

  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:exports_directory) { AWS_CONFIG[:s3_browser][:csv_exports_directory] }

  before { allow(job).to receive(:s3_client).and_return(s3_client) }

  # The job writes a real CSV file to the exports directory (specified in atc.yml); remove anything it created.
  after do
    Dir.glob(File.join(exports_directory, 'csv_export_*.csv')).each { |path| FileUtils.rm_f(path) }
  end

  def written_csv(csv_export)
    CSV.read(File.join(exports_directory, csv_export.path_to_csv_file))
  end

  describe '#perform' do
    context 'with a folder and a file that can be read' do
      let(:csv_export) do
        FactoryBot.create(
          :csv_export,
          export_paths: [{ bucket: 'test-bucket', keys: ['reports/a.txt'], prefixes: ['photos/'] }].to_json
        )
      end

      before do
        s3_client.stub_responses(:list_objects_v2, {
          contents: [
            { key: 'photos/', size: 0, last_modified: Time.zone.parse('2026-01-01'), storage_class: 'STANDARD' },
            { key: 'photos/img1.jpg', size: 2048, last_modified: Time.zone.parse('2026-01-02'),
              storage_class: 'STANDARD' }
          ]
        })
        s3_client.stub_responses(:head_object, {
          content_length: 4096, last_modified: Time.zone.parse('2026-01-03'), storage_class: 'STANDARD'
        })
        job.perform(csv_export.id)
        csv_export.reload
      end

      it 'marks the export as successful' do
        expect(csv_export.status).to eq('success')
      end

      it 'records no errors' do
        expect(csv_export.export_errors).to eq([])
      end

      it 'writes a CSV row for each collected object, skipping the folder marker' do
        s3_uris = written_csv(csv_export).drop(1).map(&:first)
        expect(s3_uris).to contain_exactly('s3://test-bucket/photos/img1.jpg', 's3://test-bucket/reports/a.txt')
      end
    end

    context 'with an INTELLIGENT_TIERING object in a folder' do
      let(:csv_export) do
        FactoryBot.create(
          :csv_export,
          export_paths: [{ bucket: 'test-bucket', keys: [], prefixes: ['archive/'] }].to_json
        )
      end

      before do
        s3_client.stub_responses(:list_objects_v2, {
          contents: [
            { key: 'archive/doc.pdf', size: 1024, last_modified: Time.zone.parse('2026-01-01'),
              storage_class: 'INTELLIGENT_TIERING' }
          ]
        })
        s3_client.stub_responses(:head_object, { archive_status: 'ARCHIVE_ACCESS', restore: nil })
        job.perform(csv_export.id)
        csv_export.reload
      end

      it 'looks up and reports the intelligent tiering storage tier' do
        csv = written_csv(csv_export)
        storage_tier = csv.drop(1).first[csv.first.index('Storage tier')]
        expect(storage_tier).to eq('Intelligent Tiering (Archive Access)')
      end
    end

    context 'when one of the objects cannot be read' do
      let(:test_s3_error) do
        Aws::S3::Errors::ServiceError.new(
          Seahorse::Client::RequestContext.new(http_response: Seahorse::Client::Http::Response.new(status_code: 500)),
          'Test error'
        )
      end
      let(:csv_export) do
        FactoryBot.create(
          :csv_export,
          export_paths: [{ bucket: 'test-bucket', keys: ['missing.txt'], prefixes: ['photos/'] }].to_json
        )
      end

      before do
        s3_client.stub_responses(:list_objects_v2, {
          contents: [
            { key: 'photos/img1.jpg', size: 2048, last_modified: Time.zone.parse('2026-01-02'),
              storage_class: 'STANDARD' }
          ]
        })
        allow(s3_client).to receive(:head_object).and_raise(test_s3_error)
        job.perform(csv_export.id)
        csv_export.reload
      end

      it 'marks the export as completed_with_errors' do
        expect(csv_export.status).to eq('completed_with_errors')
      end

      it 'records the S3 URI of the object that failed' do
        expect(csv_export.export_errors.join).to include('s3://test-bucket/missing.txt')
      end

      it 'still writes the objects it could read' do
        s3_uris = written_csv(csv_export).drop(1).map(&:first)
        expect(s3_uris).to eq(['s3://test-bucket/photos/img1.jpg'])
      end
    end

    context 'when the export cannot be processed at all' do
      let(:csv_export) { FactoryBot.create(:csv_export, export_paths: 'not-valid-json') }

      before do
        job.perform(csv_export.id)
        csv_export.reload
      end

      it 'marks the export as failed' do
        expect(csv_export.status).to eq('failure')
      end

      it 'records the error message' do
        expect(csv_export.export_errors).not_to be_empty
      end
    end
  end
end
