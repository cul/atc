import { faker } from '@faker-js/faker';

export type BucketItem =
  | {
      type: 'folder';
      name: string;
      fullPath: string;
    }
  | {
      type: 'object';
      name: string;
      fullPath: string;
      size: number;
      lastModified: string;
      storageClass: string;
    };

const STORAGE_CLASSES = [
  'STANDARD',
  'STANDARD_IA',
  'ONEZONE_IA',
  'INTELLIGENT_TIERING',
  'GLACIER',
  'GLACIER_IR',
  'DEEP_ARCHIVE',
] as const;

const EXTENSIONS = [
  '.json',
  '.csv',
  '.png',
  '.jpg',
  '.log',
  '.txt',
  '.zip',
  '.yaml',
  '.xml',
  '.pdf',
  '.bin',
] as const;

function makeFolder(): BucketItem {
  const segments = faker.helpers.multiple(
    () => faker.word.noun().toLowerCase(),
    { count: faker.number.int({ min: 1, max: 4 }) },
  );
  const fullPath = segments.join('/') + '/';
  const name = segments[segments.length - 1] + '/';

  return { type: 'folder', name, fullPath };
}

function makeObject(): BucketItem {
  const dirDepth = faker.number.int({ min: 0, max: 5 });
  const dirSegments = faker.helpers.multiple(
    () => faker.word.noun().toLowerCase(),
    { count: dirDepth },
  );
  const ext = faker.helpers.arrayElement(EXTENSIONS);
  const baseName = faker.system.fileName().replace(/\.[^.]+$/, '') + ext;
  const fullPath = [...dirSegments, baseName].join('/');

  return {
    type: 'object',
    name: baseName,
    fullPath,
    size: faker.number.int({ min: 0, max: 5_368_709_120 }), // 0 – 5 GB
    lastModified: faker.date
      .between({ from: '2020-01-01', to: new Date() })
      .toISOString(),
    storageClass: faker.helpers.arrayElement(STORAGE_CLASSES),
  };
}

export function makeData(count: number): BucketItem[] {
  return faker.helpers.multiple(
    () => (faker.datatype.boolean(0.2) ? makeFolder() : makeObject()),
    { count },
  );
}