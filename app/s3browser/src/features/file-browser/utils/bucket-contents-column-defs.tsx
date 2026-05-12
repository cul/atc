import { Link } from 'react-router'
import { createColumnHelper } from '@tanstack/react-table'
import { BucketItem } from '@/types/api'

const columnHelper = createColumnHelper<BucketItem>()

// TODO
// const extractFileExtension = (fileName: string) => {}

// const formatSize = (sizeInBytes: number) => {}

export const columnDefs = [
  columnHelper.accessor('name', {
    header: 'Name',
    // TODO: For folders, link to the folder path. For files, link to a file details page (not implemented yet).
    cell: ({ row }) => (
      <Link
        to={{ pathname: `/buckets/${encodeURIComponent(row.original.name)}` }}
        className="link-underline link-underline-opacity-0 link-underline-opacity-75-hover"
      >
        <span>{row.original.name}</span>
      </Link>
    )
  }),
  columnHelper.accessor('lastModified', {
    header: 'Last Modified',
    // TODO: Format the timestamp into a human-readable date/time string
    cell: (info) => info.getValue(),
  }),
  columnHelper.accessor('type', {
    header: 'Type',

    // TODO: For files, display file extension
    cell: ({ getValue }) => (getValue() === 'folder' ? 'Folder' : 'File'),
  }),
  columnHelper.accessor('storageClass', {
    header: 'Storage Class',
    cell: (info) => info.getValue(),
  }),
  columnHelper.accessor('size', {
    header: 'Size',
    // TODO: Format the size
    cell: (info) => info.getValue(),
  }),
]
