import type {
  Bucket,
  S3Object,
  BucketContentsResponse,
  ObjectDetails,
  CsvExportSummariesResponse,
  CsvExportSummary,
  CsvExportStatus,
  CsvExportSummariesPagination,
  CsvExportDetailsResponse,
  ExportPath,
} from '@/types/api';

const BUCKET_DEFAULTS: Bucket = {
  name: 'test-bucket',
  description: 'A test bucket for unit tests',
};

export const buildBucket = (overrides?: Partial<Bucket>): Bucket => ({
  ...BUCKET_DEFAULTS,
  ...overrides,
});

const S3_OBJECT_DEFAULTS: S3Object = {
  key: 'test-object.txt',
  size: 1024,
  lastModified: '2026-01-15T10:30:00.000Z',
  storageClass: 'STANDARD',
};

export const buildS3Object = (overrides?: Partial<S3Object>): S3Object => ({
  ...S3_OBJECT_DEFAULTS,
  ...overrides,
});

// Build an array of S3 objects with sequentially numbered names (object-000.txt, object-001.txt, etc.)
export const buildS3Objects = (count: number): S3Object[] =>
  Array.from({ length: count }, (_, i) =>
    buildS3Object({ key: `object-${String(i).padStart(3, '0')}.txt` }),
  );

// Build a full bucket-contents API response
export const buildBucketContents = (
  overrides?: Partial<BucketContentsResponse>,
): BucketContentsResponse => ({
  files: [],
  folders: [],
  ...overrides,
});

const OBJECT_DETAILS_DEFAULTS: ObjectDetails = {
  key: 'documents/report.pdf',
  bucket: 'test-bucket',
  size: 2048,
  contentType: 'application/pdf',
  lastModified: '2026-01-15T10:30:00.000Z',
  storageClass: 'STANDARD',
  archiveStatus: null,
  restoreStatus: null,
};

export const buildObjectDetails = (overrides?: Partial<ObjectDetails>): ObjectDetails => ({
  ...OBJECT_DETAILS_DEFAULTS,
  ...overrides,
});

// CSV Exports
const CSV_EXPORT_SUMMARY_PAGINATION_DEFAULTS: CsvExportSummariesPagination = {
  currentPage: 1,
  perPage: 20,
  totalPages: 1,
  totalCount: 3,
};

const CSV_EXPORT_SUMMARY_DEFAULTS: CsvExportSummary = {
  id: 1,
  status: 'success' as CsvExportStatus,
  selectionSummary: {
    sample: ['a/b/file.txt'],
    totalCount: 1,
  },
  updatedAt: '2026-01-15T10:30:00.000Z',
};

export const buildCsvExportSummary = (overrides?: Partial<CsvExportSummary>): CsvExportSummary => ({
  ...CSV_EXPORT_SUMMARY_DEFAULTS,
  ...overrides,
});

// Builds an array of 3 export summaries for the export summary response object
export const buildCsvExportSummaryArray = (count: number, start = 0): Array<CsvExportSummary> =>
  Array.from({ length: count }, (_, i) => {
    const index = start + i;
    return buildCsvExportSummary({
      id: index,
      selectionSummary: {
        sample: [`a/b/file-${index}.txt`, `c/d/file-${index}.txt`],
        totalCount: 2,
      },
    });
  });

const CSV_EXPORT_SUMMARIES_RESPONSE_DEFAULTS: CsvExportSummariesResponse = {
  csvExports: buildCsvExportSummaryArray(3),
  pagination: CSV_EXPORT_SUMMARY_PAGINATION_DEFAULTS,
};

export const buildCsvExportSummaryResponse = (
  overrides?: Partial<CsvExportSummariesResponse>,
): CsvExportSummariesResponse => ({
  ...CSV_EXPORT_SUMMARIES_RESPONSE_DEFAULTS,
  ...overrides,
});

const CSV_EXPORT_PATH_DEFAULTS: ExportPath = {
  bucket: 'bucket-a',
  keys: ['a/b/file1.txt', 'a/b/file2.txt'],
  prefixes: ['a/b/c/'],
};

const buildCsvExportPath = (overrides?: Partial<ExportPath>) => ({
  ...CSV_EXPORT_PATH_DEFAULTS,
  ...overrides,
});

const CSV_EXPORT_DETAILS_DEFAULTS: CsvExportDetailsResponse = {
  id: 1,
  exportPaths: [buildCsvExportPath(), buildCsvExportPath({ bucket: 'bucket-b' })],
  exportErrors: [],
  status: 'success',
  updatedAt: '2026-01-15T10:30:00.000Z',
};

export const buildCsvExportDetailsResponse = (overrides?: Partial<CsvExportDetailsResponse>) => ({
  ...CSV_EXPORT_DETAILS_DEFAULTS,
  ...overrides,
});
