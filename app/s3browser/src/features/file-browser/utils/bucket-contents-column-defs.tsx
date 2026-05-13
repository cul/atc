import { Link } from 'react-router'
import { createColumnHelper } from '@tanstack/react-table'
import { BucketItem } from '@/types/api'

const columnHelper = createColumnHelper<BucketItem>()

// TODO: These formatting functions could be moved to a shared utils file if we need them elsewhere in the app.
const capitalizeStr = (str: string) => {
  return str.toLowerCase()
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

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

const formatSize = (sizeInBytes: number) => {
  const units = ['B', 'kB', 'MB', 'GB', 'TB'];
  let size = sizeInBytes;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  return `${size.toFixed(2)} ${units[unitIndex]}`;
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
      const pathWithBucket = `${bucket}?prefix=${row.original.fullPath}`;
      const url = row.original.type === 'folder' ? `/buckets/${pathWithBucket}` : `/object/${pathWithBucket}`;

      return (
        <Link
          to={url}
          className="link-underline link-underline-opacity-0 link-underline-opacity-75-hover"
        >
          <span>{row.original.name}</span>
        </Link>
      );
    },
  }),
  columnHelper.accessor('lastModified', {
    header: 'Last Modified',
    cell: (info) => {
      if (!info.getValue()) return '-';
      console.log(info.getValue());

      return formatLastModified(info.getValue() as string);
    },
    sortingFn: 'datetime',
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
