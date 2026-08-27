export type CsvExportStatus = 'checked' | 'unchecked' | 'partial';

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
  updatedAt: Date;
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
  updatedAt: Date;
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
