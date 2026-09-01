import { createColumnHelper } from '@tanstack/react-table';
import { CsvExportSummaryRow } from './csv-exports-utils';
import { formatLastModified } from '@/features/file-browser/utils/format-utils';
import { Link } from 'react-router';
import DownloadButton from '@/components/ui/download-button';

const columnHelper = createColumnHelper<CsvExportSummaryRow>();

const getDetailsLinkElement = (id: number | string, linkText: string) => (
  <Link
    to={{ pathname: `${encodeURIComponent(id)}` }}
    className="link-underline link-underline-opacity-0 link-underline-opacity-75-hover"
  >
    {linkText}
  </Link>
);

export const columnDefs = [
  columnHelper.accessor('id', {
    header: 'ID',
    cell: ({ row }) => {
      const id = String(row.original.id);
      return getDetailsLinkElement(id, id);
    },
  }),
  columnHelper.accessor('status', {
    header: 'Export Status',
    cell: ({ row }) => {
      return (
        <>
          {row.original.status}
          {(row.original.status === 'success' ||
            row.original.status === 'completed_with_errors') && (
            <DownloadButton
              endpoint={`/api/csv_exports/${row.original.id}/download`}
              defaultFilename={`csv_export_${row.original.id}.csv`}
              styles="ms-2 btn-sm"
              variant="outline-primary"
            />
          )}
        </>
      );
    },
  }),
  columnHelper.accessor('selectionSample', {
    header: 'Selected Items',
    size: 500,
    cell: ({ row, column }) => {
      return (
        <div style={{ maxWidth: column.getSize(), overflowWrap: 'break-word' }}>
          <ul>
            {row.original.selectionSample.map((sample, i) => (
              <li key={i}>{sample}</li>
            ))}
          </ul>
          {row.original.selectionSample.length < row.original.totalCount && (
            <span className="fst-italic">
              ... (view {getDetailsLinkElement(row.original.id, 'export details')} for full
              selection)
            </span>
          )}
        </div>
      );
    },
  }),
  columnHelper.accessor('totalCount', {
    header: 'Total Selected Items',
    cell: ({ row }) => {
      return row.original.totalCount;
    },
  }),
  columnHelper.accessor('updatedAt', {
    header: 'Last Updated',
    cell: ({ row }) => {
      return formatLastModified(row.original.updatedAt);
    },
  }),
];
