import { useParams } from 'react-router';
import { Spinner } from 'react-bootstrap';

import {
  CsvExportStatus,
  getNumberItemsSelected,
  getTextColorFromStatus,
} from '../utils/csv-exports-utils';
import { useCsvExportDetailsQuery } from '../api/get-csv-export-details';
import ObjectDetailField from '@/features/file-browser/components/object-detail-field';
import { formatLastModified } from '@/features/file-browser/utils/format-utils';
import ExportPathsDisplayTable from './export-paths-display-table';
import DownloadButton from '@/components/ui/download-button';

const CsvExportDetailsDisplay = () => {
  const { id } = useParams();
  const { data, isLoading } = useCsvExportDetailsQuery({ exportId: id });

  if (isLoading)
    return (
      <Spinner animation="border" role="status">
        <span className="visually-hidden">Loading...</span>
      </Spinner>
    );

  const { status, exportErrors, exportPaths, updatedAt } = data;

  return (
    <div className="pt-2">
      <h4>CSV Export Details</h4>
      <section className="border rounded p-3 mb-4">
        <dl className="mb-0">
          <ObjectDetailField
            label="Export Status"
            value={
              <span className={`text-${getTextColorFromStatus(status as CsvExportStatus)}`}>
                {status.toUpperCase()}
              </span>
            }
          />
          {(status === 'success' || status === 'completed_with_errors') && (
            <ObjectDetailField
              label="Download Report"
              value={
                <DownloadButton
                  endpoint={`/api/csv_exports/${id}/download`}
                  defaultFilename={`csv_export_${id}.csv`}
                />
              }
            />
          )}
          <ObjectDetailField label="Export ID" value={id} />
          <ObjectDetailField
            label="Number of Items Selected"
            value={getNumberItemsSelected(exportPaths)}
            hint="This is a count of the folders and files in the original selection when the CSV Export was ordered. Selected folders are counted once in this figure; the final export will have a record for each child item of any selected folders and will therefore be larger in most cases."
          />
          <ObjectDetailField label="Last Updated" value={formatLastModified(updatedAt)} />
          {exportErrors.length > 0 && (
            <ObjectDetailField label="Export Errors" value={exportErrors} />
          )}
          <ObjectDetailField
            label="Export Paths"
            value={<ExportPathsDisplayTable exportPaths={exportPaths} />}
          />
        </dl>
      </section>
    </div>
  );
};

export default CsvExportDetailsDisplay;
