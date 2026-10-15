import type { Bucket, S3Object, BucketContentsResponse, ObjectDetails } from '@/types/api';

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
