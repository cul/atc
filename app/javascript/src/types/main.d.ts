import '@tanstack/react-table';

// Extends the tanstack table header column to accept a text align attribute
// https://github.com/TanStack/table/discussions/4439
declare module '@tanstack/react-table' {
  interface ColumnMeta {
    textAlign: 'left' | 'center' | 'right';
  }
}
