import '@tanstack/react-table';

// Extends the tanstack table header column to accept a text align attribute
declare module '@tanstack/table-core' {
  interface ColumnMeta<TData extends RowData, TValue> {
    textAlign: 'left' | 'center' | 'right';
  }
}
