import { createColumnHelper } from '@tanstack/react-table';
import { CsvExportSummary, CsvExportSummaryRow } from './csv-exports-utils';

const columnHelper = createColumnHelper<CsvExportSummaryRow>();

export const columnDefs = [
  columnHelper.accessor('id', {
    header: 'ID',
    cell: ({ row }) => {
      return row.original.id;
    },
  }),
  columnHelper.accessor('status', {
    header: 'Export Status',
    cell: ({ row }) => {
      return row.original.status;
    },
  }),
  columnHelper.accessor('selectionSample', {
    header: 'Selected Items',
    cell: ({ row }) => {
      return (
        <ul>
          {row.original.selectionSample.map((sample) => (
            <li>{sample}</li>
          ))}
        </ul>
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
      return row.original.updatedAt;
    },
  }),
];
