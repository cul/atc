
import { BucketContentsResponse, BucketItem } from '@/types/api';

const extractName = (fullPath: string): string => {
  const trimmed = fullPath.endsWith('/') ? fullPath.slice(0, -1) : fullPath;
  const lastSlash = trimmed.lastIndexOf('/');
  return lastSlash === -1 ? trimmed : trimmed.slice(lastSlash + 1);
};

// This function transforms the raw API response for bucket contents into a format suitable for the table component.
// The API currently returns separate lists for folders and objects, but the table expects a single list of items.
export const toBucketItems = (response: BucketContentsResponse): BucketItem[] => {
  const folderItems: BucketItem[] = response.folders.map((prefix) => ({
    type: 'folder',
    name: extractName(prefix),
    fullPath: prefix,
  }));
 
  const objectItems: BucketItem[] = response.objects.map((obj) => ({
    type: 'object',
    name: extractName(obj.key),
    fullPath: obj.key,
    size: obj.size,
    storageClass: obj.storageClass,
    lastModified: obj.lastModified,
  }));
 
  // TODO: Let TanStack Table handle initial sorting?
  return [...folderItems, ...objectItems].sort((a, b) => a.name.localeCompare(b.name));
};