import { Link } from 'react-router';
import { createColumnHelper } from '@tanstack/react-table';
import { BucketItem } from '@/types/api';
import {
  capitalizeStr,
  extractFileExtension,
  formatSize,
  formatLastModified,
} from './format-utils';
import SelectionCheckbox from '../components/selection-checkbox';
import SelectAllCheckbox from '../components/select-all-checkbox';

const columnHelper = createColumnHelper<BucketItem>();

const sortByTypeAndExtension = (a: BucketItem, b: BucketItem) => {
  if (a.type !== b.type) {
    return a.type === 'folder' ? -1 : 1;
  }

  if (a.type === 'object' && b.type === 'object') {
    const extensionA = extractFileExtension(a.name).toLowerCase();
    const extensionB = extractFileExtension(b.name).toLowerCase();

    const extensionComparison = extensionA.localeCompare(extensionB);
    if (extensionComparison !== 0) {
      return extensionComparison;
    }
  }

  return a.name.localeCompare(b.name);
};

export const columnDefs = (bucket: string) => [
  columnHelper.display({
    id: 'select',
    header: () => <SelectAllCheckbox />,
    meta: { textAlign: 'center' },
    cell: (props) => <SelectionCheckbox row={props.row} />,
  }),
  columnHelper.accessor('name', {
    header: 'Name',
    cell: ({ row }) => {
      const bucketPath = `/browse/buckets/${bucket}`;
      const prefix = row.original.fullPath
        ? `?prefix=${encodeURIComponent(row.original.fullPath)}`
        : '';
      const url =
        row.original.type === 'folder'
          ? `${bucketPath}${prefix}`
          : `${bucketPath}/object-details${prefix}`;

      return (
        <Link
          to={url}
          className="link-underline link-underline-opacity-0 link-underline-opacity-75-hover"
        >
          <span>{row.original.name}</span>
        </Link>
      );
    },
    sortingFn: 'alphanumeric',
  }),
  columnHelper.accessor('lastModified', {
    header: 'Last Modified',
    cell: (info) => {
      if (!info.getValue()) return '-';

      return formatLastModified(info.getValue() as string);
    },
    sortingFn: 'datetime', // This is the slowest part of our sorting
    sortDescFirst: false,
    sortUndefined: 'last',
  }),
  columnHelper.accessor('type', {
    header: 'Type',
    cell: ({ row }) =>
      row.original.type === 'folder' ? 'Folder' : extractFileExtension(row.original.name),
    // Sorts folders first, then sorts objects by file extension
    sortingFn: (rowA, rowB) => sortByTypeAndExtension(rowA.original, rowB.original),
  }),
  columnHelper.accessor('storageClass', {
    header: 'Storage Class',
    cell: ({ row }) =>
      row.original.type === 'object' ? capitalizeStr(row.original.storageClass) : '-',
    sortDescFirst: false,
    sortUndefined: 'last',
  }),
  columnHelper.accessor('size', {
    header: 'Size',
    cell: (info) => {
      const row = info.row.original;
      return row.type === 'object' ? formatSize(info.getValue() as number) : '-';
    },
    sortDescFirst: false,
    sortUndefined: 'last',
  }),
];
