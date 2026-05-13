import { Link } from 'react-router'
import { createColumnHelper } from '@tanstack/react-table'
import { Bucket } from '@/types/api'

const columnHelper = createColumnHelper<Bucket>()

export const columnDefs = [
  columnHelper.accessor('bucket', {
    header: 'Name',
    cell: ({ row }) => (
      <Link
        to={{ pathname: `/buckets/${encodeURIComponent(row.original.bucket)}` }}
        className="link-underline link-underline-opacity-0 link-underline-opacity-75-hover"
      >
        <span>{row.original.bucket}</span>
      </Link>
    )
  }),
  columnHelper.accessor('description', {
    header: 'Description',
    cell: (info) => info.getValue(),
    enableSorting: false
  }),
]
