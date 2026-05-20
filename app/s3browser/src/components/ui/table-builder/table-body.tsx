import { ColumnDef, useReactTable } from '@tanstack/react-table'
import Spinner from 'react-bootstrap/Spinner';
import TableRow from './table-row'

type TableBodyProps<T> = {
  table: ReturnType<typeof useReactTable<T>>;
  columns: ColumnDef<T>[];
  isLoading?: boolean;
}

const TableBody = <T extends object>({
  table,
  columns,
  isLoading,
}: TableBodyProps<T>) => {
  if (isLoading) {
    return (
      <tbody>
        <tr>
          <td colSpan={columns.length} className="text-center py-3">
            <Spinner animation="border" role="status">
              <span className="visually-hidden">Loading...</span>
            </Spinner>
          </td>
        </tr>
      </tbody>
    );
  }

  const rows = table.getRowModel().rows;

  if (rows.length === 0) {
    return (
      <tbody>
        <tr>
          <td colSpan={columns.length} className="text-center py-3">
            No entries found.
          </td>
        </tr>
      </tbody>
    );
  }

  return (
    <tbody>
      {rows.map((row) => (
        <TableRow row={row} key={row.id} />
      ))}
    </tbody>
  );
};

export default TableBody;