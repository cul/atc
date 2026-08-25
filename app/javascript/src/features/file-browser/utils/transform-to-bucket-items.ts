import { BucketContentsResponse, BucketItem } from '@/types/api';
import { extractName } from './format-utils';

// This function transforms the raw API response for bucket contents into a format suitable for the table component.
// The API currently returns separate lists for folders and objects, but the table expects a single list of items.
export const toBucketItems = (response: BucketContentsResponse): BucketItem[] => {
  const folderItems: BucketItem[] = response.folders.map((prefix) => ({
    type: 'folder',
    name: extractName(prefix),
    fullPath: prefix,
  }));

  const objectItems: BucketItem[] = response.files.map((obj) => ({
    type: 'object',
    name: extractName(obj.key),
    fullPath: obj.key,
    size: obj.size,
    storageClass: obj.storageClass,
    lastModified: obj.lastModified,
  }));

  return [...folderItems, ...objectItems];
};
