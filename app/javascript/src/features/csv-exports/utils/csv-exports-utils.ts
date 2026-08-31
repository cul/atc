// Options matching the statuses in the csv_export model
export type CsvExportStatus =
  | 'pending'
  | 'processing'
  | 'success'
  | 'failure'
  | 'completed_with_errors';

export type BucketSelection = {
  bucket: string;
  keys: Array<string>;
  prefixes: Array<string>;
};

export type CsvExportDetails = Omit<CsvExportSummary, 'selectionSummary'> & {
  exportPaths: Array<BucketSelection>;
  exportErrors: Array<string>;
};

export type CsvExportSummary = {
  id: number;
  status: CsvExportStatus;
  selectionSummary: {
    sample: Array<string>;
    totalCount: number;
  };
  updatedAt: string;
};

export type CsvExportSummariesResponse = {
  csvExports: Array<CsvExportSummary>;
  pagination: CsvExportSummariesPagination;
};

export type CsvExportSummariesPagination = {
  currentPage: number;
  perPage: number;
  totalPages: number;
  totalCount: number;
};

// Will need to transform API response into this flat object
export type CsvExportSummaryRow = {
  id: number;
  status: CsvExportStatus;
  selectionSample: Array<string>;
  totalCount: number;
  updatedAt: string;
};

export const transformCsvExportSummaryToRow = (
  csvExport: CsvExportSummary,
): CsvExportSummaryRow => ({
  id: csvExport.id,
  status: csvExport.status,
  selectionSample: csvExport.selectionSummary.sample,
  totalCount: csvExport.selectionSummary.totalCount,
  updatedAt: csvExport.updatedAt,
});

export const DEFAULT_CSV_EXPORT_PAGE_SIZE = 20;

export type ExportPath = {
  bucket: string;
  keys: Array<string>;
  prefixes: Array<string>;
};

export type CsvExportDetailsResponse = {
  id: number;
  exportPaths: Array<ExportPath>;
  exportErrors: Array<string>;
  status: string;
  updatedAt: string;
};

export type FullExportItem = {
  number?: number;
  bucket: string;
  uri: string;
  type: 'file' | 'folder';
};

// Take the array of Export Path objects and flatten them for use in the
// export paths table on csv export detail pages
export const convertToFullExportPathsList = (
  exportPaths: Array<ExportPath>,
): Array<FullExportItem> => {
  const results = [];
  exportPaths.forEach((exportPath) => {
    exportPath.prefixes.forEach((folder) => {
      results.push({
        bucket: exportPath.bucket,
        uri: folder,
        type: 'folder',
      });
    });
    exportPath.keys.forEach((file) => {
      results.push({
        bucket: exportPath.bucket,
        uri: file,
        type: 'file',
      });
    });
  });
  return results;
};

export const getNumberItemsSelected = (exportPaths: Array<ExportPath>) => {
  let count = 0;
  exportPaths.forEach((exportPath) => {
    count += exportPath.prefixes.length;
    count += exportPath.keys.length;
  });
  return count;
};

export const getTextColorFromStatus = (status: CsvExportStatus) => {
  switch (status) {
    case 'failure':
      return 'danger';
    case 'success':
      return 'success';
    default:
      return 'warning';
  }
};
