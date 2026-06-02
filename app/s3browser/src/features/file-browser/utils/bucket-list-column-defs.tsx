import { Link } from 'react-router'
import { createColumnHelper } from '@tanstack/react-table'
import { Bucket } from '@/types/api'

const columnHelper = createColumnHelper<Bucket>()

export const columnDefs = [
  columnHelper.accessor('name', {
    header: 'Name',
    cell: ({ row }) => (
      <Link
        to={{ pathname: `${encodeURIComponent(row.original.name)}` }}
        className="link-underline link-underline-opacity-0 link-underline-opacity-75-hover"
      >
        <span>{row.original.name}</span>
      </Link>
    )
  }),
  columnHelper.accessor('description', {
    header: 'Description',
    cell: (info) => info.getValue(),
    enableSorting: false
  }),
]
