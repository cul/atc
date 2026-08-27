import { useNotifications } from '@/stores/notifications-store';
import { BucketSelection, CheckboxState } from '@/stores/selected-items-store';
import { BucketItem } from '@/types/api';

// Returns an array of the current folder or file's ancestors in order of
// closest to furthest (highest)
// e.g. 'a/b/c/d/' -> [ 'a/b/c/', 'a/b/', 'a/', '/' ]
export const getAncestors = (
  item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
): Array<string> => {
  const ancestors = [];
  let path = item.fullPath;
  // Do not include the current item itself (if it is a folder)
  if (item.type === 'folder') path = path.substring(0, path.lastIndexOf('/'));
  while (path.includes('/')) {
    const nextAncestor = path.substring(0, path.lastIndexOf('/'));
    ancestors.push(`${nextAncestor}/`);
    path = nextAncestor;
  }
  ancestors.push('/'); // The bucket itself
  return ancestors;
};

// Returns array of the current folder or file's ancestors up until the cap
// in order of closest to furthest (highest)
// e.g. ('a/b/c/d/', 'a/') -> [ 'a/b/c/', 'a/b/', 'a/']
export const getAncestorsBetween = (
  item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
  limit: string,
) => {
  const ancestors = [];
  let path = item.fullPath;
  // Do not include the current item itself (if it is a folder)
  if (item.type === 'folder') path = path.substring(0, path.lastIndexOf('/'));
  while (`${path}/` !== limit) {
    const nextAncestor = path.substring(0, path.lastIndexOf('/'));
    ancestors.push(`${nextAncestor}/`);
    path = nextAncestor;
  }
  return ancestors;
};

// Remove prefix from path and return remainder
export const subtractPrefix = (path: string, prefix: string) => path.replace(prefix, '');

// Returns true if path is the direct child of prefix
export const isDirectChildOf = (path: string, prefix: string) => {
  if (path.endsWith('/')) path = path.slice(0, -1); // Remove trailing / for folders
  // Base case: top level of a bucket
  if (prefix === '/') {
    return !path.includes('/');
  }
  return path.startsWith(prefix) && !subtractPrefix(path, prefix).includes('/');
};

// Returns count of folders and files in the selection store that are direct children of prefix
export const countSelectedAncestorChildren = (
  nextFolders: Set<string>,
  nextFiles: Set<string>,
  prefix: string,
) => {
  let count = 0;
  for (const path of nextFolders) if (isDirectChildOf(path, prefix)) count++;
  for (const path of nextFiles) if (isDirectChildOf(path, prefix)) count++;
  return count;
};

// Is path a child of prefix? It is if path's uri begins with prefix.
export const isAnyChildOf = (path: string, prefix: string) => {
  // Everything is a child of the root level, but the items don't startWith('/')
  if (prefix === '/') return true;
  return path.startsWith(prefix);
};

// Returns the selected folder that contains this item marked for deselection
// (if such a folder exists)
// This works because if there is a selected folder that contains this item marked
// for deselection, that folder will be a complete substring of the item's path
export const getNearestSelectedParent = (path: string, folders: Set<string>) => {
  for (const folder of folders) {
    if (path.startsWith(folder)) return folder;
  }
  // base case: the nearest selected parent is the entire bucket
  if (folders.has('/')) return '/';
};

// Logic for determining what state a selection checkbox should be
export const checkboxState = (
  currentBucket: BucketSelection | undefined,
  item: BucketItem,
): CheckboxState => {
  if (currentBucket === undefined) return 'unchecked';
  const { folders, files } = currentBucket;

  // Exact folder or item match
  if (folders.has(item.fullPath) || files.has(item.fullPath)) return 'checked';

  // If the current item is the root level folder of a bucket & should be partial
  if (item.type === 'folder' && item.fullPath === '/' && (folders.size > 0 || files.size > 0))
    return 'partial';

  // Item is contained in a selected folder, i.e. are any of it's ancestors included in the selected folders
  if (getAncestors(item).some((ancestor) => folders.has(ancestor))) return 'checked';

  // Item is a folder and some selected files or folders are contained within it --> partial
  if (item.type === 'folder') {
    for (const folder of folders) if (folder.startsWith(item.fullPath)) return 'partial';
    for (const file of files) if (file.startsWith(item.fullPath)) return 'partial';
  }

  return 'unchecked';
};

export const notifySelectionError = (errorMessage: string) => {
  useNotifications.getState().addNotification({
    type: 'error',
    title: `Error Selecting Item`,
    message: errorMessage,
  });
};

export const notifyNewCsvExport = (exportId: string) => {
  useNotifications.getState().addNotification({
    type: 'success',
    title: `Your Export has been ordered`,
    message: `Your new CSV Export with ID ${exportId} has been ordered.`,
    linkValue: `/csv_exports/${exportId}`,
    linkText: 'View export details.',
  });
};

// Returns count of all items in the selection store -- the number of selected items
// means selected folders and selected files, not the total amount of files contained
// in the selection (i.e., a folder counts as one item, we do not count how many
// children it has -- we may add that in the future).
export const getFullSelectionCount = (buckets: BucketSelection[]) => {
  let count = 0;
  buckets.forEach((bucket) => {
    count += bucket.folders.size;
    count += bucket.files.size;
  });
  return count;
};

// Returns count of all items in the selected for a particular bucket -- the number
// of selected items means selected folders and selected files, not the total amount
// of files contained in the selection (i.e., a folder counts as one item, we
// do not count how many children it has -- we may add that in the future).
export const getBucketSelectionCount = (bucket: BucketSelection) => {
  let count = 0;
  count += bucket.folders.size;
  count += bucket.files.size;
  return count > 1 ? `${count} selections` : `1 selection`;
};

// Format for request body to backend CSV export endpoint
export type SelectionCsvExportBody = {
  selections: Array<BucketSelectionCsvExportJSON>;
};

type BucketSelectionCsvExportJSON = {
  bucket: string;
  files: string[];
  directories: string[];
};

// Convert the selection store to the correct data shape for a request to the
// backend CSV export endpoint
export const csvExportReqBody = (buckets: BucketSelection[]): SelectionCsvExportBody => {
  return {
    selections: buckets.map((bucket) => {
      return {
        bucket: bucket.bucketName,
        files: [...bucket.files],
        directories: [...bucket.folders],
      };
    }),
  };
};
