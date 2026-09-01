import { Table } from '@tanstack/react-table';
import { Pagination } from 'react-bootstrap';

interface TablePaginationProps<T> {
  table: Table<T>;
  isServerSidePaginated?: boolean; // todo: combine props to make mandatory
  rowCount?: number;
}

// Based on https://tanstack.com/table/v8/docs/framework/react/examples/pagination
// Note: If isServerSidePaginated is set to true, you must provide a rowCount as
// getFilteredRowModel returns only the rows in the current page's rows (the table
// only contains the current page because the API returns one page at a time)
function TablePagination<T>({
  table,
  isServerSidePaginated = false,
  rowCount,
}: TablePaginationProps<T>) {
  const { pageIndex, pageSize } = table.getState().pagination;
  const totalRows = isServerSidePaginated ? rowCount : table.getFilteredRowModel().rows.length;

  // An empty table has a page count of 0 but we still want to display
  // the page as "1 of 1" rather than "1 of 0", so floor the displayed count at 1.
  const pageCount = Math.max(table.getPageCount(), 1);
  const startRow = totalRows === 0 ? 0 : pageIndex * pageSize + 1;
  const endRow = Math.min((pageIndex + 1) * pageSize, totalRows);

  return (
    <Pagination className="mt-2">
      <Pagination.First onClick={() => table.firstPage()} disabled={!table.getCanPreviousPage()} />
      <Pagination.Prev
        onClick={() => table.previousPage()}
        disabled={!table.getCanPreviousPage()}
      />
      <Pagination.Item active>
        {pageIndex + 1} of {pageCount}
      </Pagination.Item>
      <Pagination.Next onClick={() => table.nextPage()} disabled={!table.getCanNextPage()} />
      <Pagination.Last onClick={() => table.lastPage()} disabled={!table.getCanNextPage()} />
      <div className="d-flex align-items-center p-2">
        Showing {startRow}-{endRow} of {totalRows}
      </div>
    </Pagination>
  );
}

export default TablePagination;
