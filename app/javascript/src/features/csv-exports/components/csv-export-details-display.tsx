import { useParams } from 'react-router';

import { getNumberItemsSelected, getTextColorFromStatus } from '../utils/csv-exports-utils';
import { useCsvExportDetailsSuspense } from '../api/get-csv-export-details';
import ObjectDetailField from '@/features/file-browser/components/object-detail-field';
import { formatLastModified } from '@/features/file-browser/utils/format-utils';
import ExportPathsDisplayTable from './export-paths-display-table';
import DownloadButton from '@/components/ui/download-button';
import { CsvExportStatus } from '@/types/api';

const CsvExportDetailsDisplay = () => {
  const { id } = useParams();
  const { data } = useCsvExportDetailsSuspense({ exportId: id });

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
          {exportErrors.length > 0 && (
            <ObjectDetailField
              label="Errors"
              value={
                <ul className="bg-danger bg-opacity-25 py-2">
                  {exportErrors.map((err, i) => (
                    <li key={i}>{err}</li>
                  ))}
                </ul>
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
