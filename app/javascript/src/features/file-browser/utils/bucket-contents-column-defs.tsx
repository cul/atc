import { Link } from 'react-router';
import { createColumnHelper, Row } from '@tanstack/react-table';
import { BucketItem } from '@/types/api';
import {
  capitalizeStr,
  extractFileExtension,
  formatSize,
  formatLastModified,
} from './format-utils';
import { useCheckboxState, useSelectedItemsStore } from '@/stores/selected-items-store';
import { useEffect, useRef, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { Spinner } from 'react-bootstrap';
import { getAncestors } from './selection-utils';
import { getBucketContentsQueryOptions } from '../api/get-bucket-contents';

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

const RowActions = ({ row }: { row: Row<BucketItem> }) => {
  const { selectItem, deselectItem } = useSelectedItemsStore();
  const queryClient = useQueryClient();
  const checkedState = useCheckboxState(row.original);
  const [pending, setPending] = useState(false);

  const executeSelection = (rowItem: BucketItem, checkedState: string) => {
    if (checkedState === 'checked') {
      deselectItem(rowItem, queryClient);
    } else {
      // checkedState === 'unchecked' || checkedState ==='partial'
      selectItem(rowItem, queryClient);
    }
  };

  const handleClick = async (rowItem: BucketItem, checkedState: string) => {
    setPending(true);
    try {
      await Promise.all(
        getAncestors(rowItem).map((ancestorPrefix) =>
          queryClient.fetchQuery({
            ...getBucketContentsQueryOptions('cul-dlstor-digital-testing1', ancestorPrefix),
          }),
        ),
      );
      executeSelection(rowItem, checkedState);
    } catch {
      // TODO: render error notification
    } finally {
      setPending(false);
    }
  };

  if (pending) return <Spinner animation="border" size="sm" variant="primary" />;

  return (
    <div>
      <input
        className="form-check-input"
        type="checkbox"
        checked={checkedState === 'checked'}
        id={`checkItem${row.id}`}
        onChange={() => handleClick(row.original, checkedState)}
      ></input>
      <label className="form-check-label" htmlFor={`checkItem${row.id}`} />
      {checkedState}
    </div>
  );
};

// non modifiable checkbox for folder selection's children
// then we only track exactly what the user does and only correct indeterminate check to full check when they manually check it off

export const columnDefs = (bucket: string) => [
  columnHelper.display({
    id: 'select', // what is the id for?
    cell: (props) => <RowActions row={props.row} />,
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
