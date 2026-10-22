import { createColumnHelper } from '@tanstack/react-table';
import { FullExportItem } from './csv-exports-utils';

const columnHelper = createColumnHelper<FullExportItem>();

export const columnDefs = [
  columnHelper.accessor('number', { header: () => '#', cell: (info) => parseInt(info.row.id) + 1 }),
  columnHelper.accessor('uri', {
    header: 'Item Path',
    cell: ({ row }) => {
      return row.original.uri;
    },
  }),
  columnHelper.accessor('bucket', {
    header: 'Bucket',
    cell: ({ row }) => {
      return row.original.bucket;
    },
  }),
  columnHelper.accessor('type', {
    header: 'Selection Type',
    cell: ({ row }) => {
      return row.original.type;
    },
  }),
];
