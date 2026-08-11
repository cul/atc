import '@tanstack/react-table';

// Extends the tanstack table header column to accept a text align attribute
// https://github.com/TanStack/table/discussions/4439
declare module '@tanstack/table-core' {
  interface ColumnMeta<TData extends RowData, TValue> {
    textAlign: 'left' | 'center' | 'right';
  }
}
