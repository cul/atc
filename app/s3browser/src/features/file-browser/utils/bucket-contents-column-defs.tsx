import { Link } from 'react-router'
import { createColumnHelper } from '@tanstack/react-table'
import { BucketItem } from '@/types/api'
import { capitalizeStr, formatSize } from './format-utils';

const columnHelper = createColumnHelper<BucketItem>()

const extractFileExtension = (fileName: string) => {
  const parts = fileName.split('.');
  return parts.length > 1 ? parts.pop() : 'unknown';
}

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
}

const formatLastModified = (dateString: string): string => {
  const date = new Date(dateString);
  const pad = (n: number) => n.toString().padStart(2, '0');

  return `${date.toLocaleString('en-US', { month: 'long' })} ${date.getDate()}, ${date.getFullYear()}, ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
};

export const columnDefs = (bucket: string) => [
  columnHelper.accessor('name', {
    header: 'Name',
    cell: ({ row }) => {
      const bucketPath = `/buckets/${bucket}`;
      const prefix = row.original.fullPath ? `?prefix=${encodeURIComponent(row.original.fullPath)}` : '';
      const url = row.original.type === 'folder' ? `${bucketPath}${prefix}` : `${bucketPath}/object-details${prefix}`;

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
    sortUndefined: 'last'
  }),
  columnHelper.accessor('type', {
    header: 'Type',
    cell: ({ row }) => row.original.type === 'folder' ? 'Folder' : extractFileExtension(row.original.name),
    // Sorts folders first, then sorts objects by file extension
    sortingFn: (rowA, rowB) => sortByTypeAndExtension(rowA.original, rowB.original),
  }),
  columnHelper.accessor('storageClass', {
    header: 'Storage Class',
    cell: ({ row }) => row.original.type === 'object' ? capitalizeStr(row.original.storageClass) : '-',
    sortDescFirst: false,
    sortUndefined: 'last'
  }),
  columnHelper.accessor('size', {
    header: 'Size',
    cell: (info) => {
      const row = info.row.original;
      return row.type === 'object' ? formatSize(info.getValue() as number) : '-';
    },
    sortDescFirst: false,
    sortUndefined: 'last'
  }),
]
