import { Table } from '@tanstack/react-table'
import { Pagination } from 'react-bootstrap'

interface TablePaginationProps<T> {
  table: Table<T>
}

// Based on https://tanstack.com/table/v8/docs/framework/react/examples/pagination
function TablePagination<T>({ table }: TablePaginationProps<T>) {
  const { pageIndex } = table.getState().pagination
  const pageCount = table.getPageCount()

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
    </Pagination>
  )
}

export default TablePagination