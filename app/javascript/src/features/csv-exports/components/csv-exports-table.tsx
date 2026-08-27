import { useSearchParams } from 'react-router';
import { useCsvExportSummariesQuery } from '../api/get-csv-export-summaries';
import { flexRender, getCoreRowModel, useReactTable } from '@tanstack/react-table';
import { transformCsvExportSummaryToRow } from '../utils/csv-exports-utils';
import { useMemo } from 'react';
// import TableBuilder from '@/components/ui/table-builder/table-builder';
import { columnDefs } from '../utils/csv-exports-column-defs';

const CsvExportsTable = () => {
  let [searchParams, setSearchParams] = useSearchParams();
  const pageIndex = searchParams.get('page') ?? '1'; // todo use default
  const perPage = searchParams.get('perPage') ?? '20'; // todo use default

  console.log('in exports table, pageIndex and perPage:');
  console.log(pageIndex);
  console.log(perPage);
  const { data, isLoading } = useCsvExportSummariesQuery({ pageIndex, perPage });

  const rowData = useMemo(() => {
    if (!data) return [];
    return data.csvExports.map((csvExport) => transformCsvExportSummaryToRow(csvExport));
  }, [searchParams, data]);

  const columns = columnDefs;
  const serverSidePaginationChange = ({ pageIndex, pageSize }) => {
    setSearchParams('page', pageIndex);
  };

  const table = useReactTable({
    data: rowData,
    columns,
    state: {
      pagination: {
        pageIndex: parseInt(pageIndex),
        pageSize: parseInt(perPage),
      },
    },
    manualPagination: true,
    onPaginationChange: serverSidePaginationChange,
    rowCount: data?.pagination.totalCount,
    getCoreRowModel: getCoreRowModel(),
  });

  if (isLoading) {
    console.log('LOADING');
    return <div>Loading...</div>;
  }
  console.log('RENDERING TABLE!');
  console.log(data);
  return (
    <div>
      <h4>
        <strong>CSV Exports</strong>
      </h4>
      <table>
        <thead>
          {table.getHeaderGroups().map((headerGroup) => (
            <tr key={headerGroup.id}>
              {headerGroup.headers.map((header) => {
                return (
                  <th key={header.id} colSpan={header.colSpan}>
                    {header.isPlaceholder ? null : (
                      <div>{flexRender(header.column.columnDef.header, header.getContext())}</div>
                    )}
                  </th>
                );
              })}
            </tr>
          ))}
        </thead>
        <tbody>
          {table.getRowModel().rows.map((row) => {
            return (
              <tr key={row.id}>
                {row.getVisibleCells().map((cell) => {
                  return (
                    <td key={cell.id}>
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  );
                })}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};

export default CsvExportsTable;
