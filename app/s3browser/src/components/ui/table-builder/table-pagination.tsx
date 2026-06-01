import { Table } from '@tanstack/react-table'
import { Pagination } from 'react-bootstrap'

interface TablePaginationProps<T> {
  table: Table<T>
}

// Based on https://tanstack.com/table/v8/docs/framework/react/examples/pagination
function TablePagination<T>({ table }: TablePaginationProps<T>) {
  const { pageIndex } = table.getState().pagination
  const pageCount = table.getPageCount()
  const startRow = pageIndex * table.getState().pagination.pageSize + 1
  const endRow = Math.min((pageIndex + 1) * table.getState().pagination.pageSize, table.getFilteredRowModel().rows.length)

  return (
    <Pagination className="mt-2">
      {/* TODO: Display how many items are being shown */}
      <Pagination.First
        onClick={() => table.firstPage()}
        disabled={!table.getCanPreviousPage()}
      />
      <Pagination.Prev
        onClick={() => table.previousPage()}
        disabled={!table.getCanPreviousPage()}
      />
      <Pagination.Item active>
        {pageIndex + 1} of {pageCount}
      </Pagination.Item>
      <Pagination.Next
        onClick={() => table.nextPage()}
        disabled={!table.getCanNextPage()}
      />
      <Pagination.Last
        onClick={() => table.lastPage()}
        disabled={!table.getCanNextPage()}
      />
      <div className="d-flex align-items-center p-2">
        Showing {startRow}-{endRow} of {table.getFilteredRowModel().rows.length}
      </div>
    </Pagination>
  )
}

export default TablePagination