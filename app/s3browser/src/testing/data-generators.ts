import type { Bucket } from '@/types/api';

// Generate bucket
const BUCKET_DEFAULTS: Bucket = {
  name: 'test-bucket',
  description: 'A test bucket for unit tests',
};

export const buildBucket = (overrides?: Partial<Bucket>): Bucket => {
  return {
    ...BUCKET_DEFAULTS,
    ...overrides,
  };
};
