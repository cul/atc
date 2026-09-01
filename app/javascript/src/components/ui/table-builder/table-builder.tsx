import { useState } from 'react';

import {
  getCoreRowModel,
  useReactTable,
  ColumnDef,
  getSortedRowModel,
  SortingState,
  getPaginationRowModel,
  PaginationState,
  Updater,
} from '@tanstack/react-table';
import { Table as BTable } from 'react-bootstrap';
import TableHeader from './table-header';
import TablePagination from './table-pagination';
import TableBody from './table-body';

interface TableBuilderProps<T> {
  data: T[];
  columns: ColumnDef<T>[];
  initialSorting?: SortingState;
  pageSize?: number;
  pagination?: PaginationState;
  onPaginationChange?: (updater: Updater<PaginationState>) => void;
  isLoading?: boolean;
  isServerSidePaginated?: boolean;
  rowCount?: number;
}

export const DEFAULT_PAGE_SIZE = 50;

// This is a generic table component that can be reused across different data types
// When using this component, ensure you specify how to render each column in the column definitions
// Docs: https://tanstack.com/table/v8/docs/guide/column-defs
// Note: when using server-side pagination (isServerSidePaginated=true), you must
// supply a rowCount
function TableBuilder<T extends object>({
  data,
  columns,
  initialSorting = [],
  pageSize = DEFAULT_PAGE_SIZE,
  pagination,
  onPaginationChange,
  isLoading,
  isServerSidePaginated = false,
  rowCount,
}: TableBuilderProps<T>) {
  // You can disable sorting specific columns or specify custom sorting functions in the column definitions
  // Docs: https://tanstack.com/table/v8/docs/api/features/sorting#column-def-options
  const [sorting, setSorting] = useState<SortingState>(initialSorting);
  const [internalPagination, setInternalPagination] = useState<PaginationState>({
    pageIndex: 0,
    pageSize,
  });

  // Determine if pagination is controlled externally (via props) or internally (via component state)
  const isPaginationControlled = pagination !== undefined && onPaginationChange !== undefined;
  const effectivePagination = isPaginationControlled ? pagination : internalPagination;
  const effectiveOnPaginationChange = isPaginationControlled
    ? onPaginationChange
    : setInternalPagination;

  const table = useReactTable<T>({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    state: {
      sorting,
      pagination: effectivePagination,
    },
    getSortedRowModel: getSortedRowModel(),
    onSortingChange: setSorting,
    onPaginationChange: effectiveOnPaginationChange,
    getPaginationRowModel: getPaginationRowModel(),
    // Prevent setting pageIndex to 0 on data changes when pagination
    // is controlled externally (eg. via URL)
    autoResetPageIndex: !isPaginationControlled,
    manualPagination: isServerSidePaginated,
    rowCount: rowCount,
  });

  return (
    <>
      {/* TODO: Keep this always above the fold */}
      <TablePagination
        table={table}
        isServerSidePaginated={isServerSidePaginated}
        rowCount={rowCount}
      />

      <BTable striped bordered hover responsive size="md" className="rounded-4">
        {table.getHeaderGroups().map((headerGroup) => (
          <TableHeader key={headerGroup.id} headerGroup={headerGroup} />
        ))}
        <TableBody table={table} columns={columns} isLoading={isLoading} />
      </BTable>
    </>
  );
}

export default TableBuilder;
