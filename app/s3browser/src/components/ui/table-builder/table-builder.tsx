import { useState } from 'react'

import {
  getCoreRowModel,
  useReactTable,
  ColumnDef,
  getSortedRowModel,
  SortingState,
  getPaginationRowModel,
  PaginationState,
  Updater,
} from '@tanstack/react-table'
import { Table as BTable } from 'react-bootstrap'
import TableHeader from './table-header'
import TableRow from './table-row'
import TablePagination from './table-pagination'

interface TableBuilderProps<T> {
  data: T[]
  columns: ColumnDef<T>[]
  initialSorting?: SortingState,
  pageSize?: number,
  pagination?: PaginationState;
  onPaginationChange?: (updater: Updater<PaginationState>) => void;
}

const DEFAULT_PAGE_SIZE = 50;

// This is a generic table component that can be reused across different data types
// When using this component, ensure you specify how to render each column in the column definitions
// Docs: https://tanstack.com/table/latest/docs/guide/column-defs
function TableBuilder<T extends object>({
  data,
  columns,
  initialSorting = [],
  pageSize = DEFAULT_PAGE_SIZE,
  pagination,
  onPaginationChange
}: TableBuilderProps<T>) {
  // You can disable sorting specific columns or specify custom sorting functions in the column definitions
  // Docs: https://tanstack.com/table/latest/docs/api/features/sorting#column-def-options
  const [sorting, setSorting] = useState<SortingState>(initialSorting)
  const [internalPagination, setInternalPagination] = useState<PaginationState>({
    pageIndex: 0,
    pageSize,
  })

  // Determine if pagination is controlled externally (via props) or internally (via component state)
  const isPaginationControlled = pagination !== undefined && onPaginationChange !== undefined;
  const effectivePagination = isPaginationControlled ? pagination : internalPagination;
  const effectiveOnPaginationChange = isPaginationControlled
    ? onPaginationChange
    : setInternalPagination

  const table = useReactTable<T>({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    state: {
      sorting,
      pagination: effectivePagination
    },
    getSortedRowModel: getSortedRowModel(),
    onSortingChange: setSorting,
    onPaginationChange: effectiveOnPaginationChange,
    getPaginationRowModel: getPaginationRowModel(),
  })

  return (
    <>
      {/* TODO: Keep this always above the fold */}
      {/* ? Don't render pagination if there's only one page */}
      <TablePagination table={table} />

      <BTable striped bordered hover responsive size="md" className="rounded-4">
        {table.getHeaderGroups().map((headerGroup) => (
          <TableHeader
            key={headerGroup.id}
            headerGroup={headerGroup} />
        ))}
        <tbody>
          {table.getRowModel().rows.length === 0 && (
            <tr>
              <td colSpan={columns.length} className="text-center py-3">
                No entries found.
              </td>
            </tr>
          )}
          {table.getRowModel().rows.map((row) => (
            <TableRow row={row} key={row.id} />
          ))}
        </tbody>
      </BTable>
    </>
  )
}

export default TableBuilder;