import { useNotifications } from '@/stores/notifications-store';
import { BucketSelection, SelectedItemsStore } from '@/stores/selected-items-store';
import { BucketItem } from '@/types/api';

// Returns an array of the current folder or object's ancestors in order of
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

// Returns array of the current folder or object's ancestors up until the cap
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

// Returns count of folders and objects in the selection store that are direct children of prefix
export const countSelectedAncestorChildren = (
  nextFolders: Set<string>,
  nextObjects: Set<string>,
  prefix: string,
) => {
  let count = 0;
  for (const path of nextFolders) if (isDirectChildOf(path, prefix)) count++;
  for (const path of nextObjects) if (isDirectChildOf(path, prefix)) count++;
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

// Logic for determining what state the select all checkbox for currentFolder should be
export const selectAllCheckboxState = (
  state: SelectedItemsStore,
  bucketName: string,
  currentFolder: string,
) => {
  const currentBucket = state.buckets.find((bucket) => bucket.bucketName === bucketName);
  if (!currentBucket) return 'unchecked';
  const { folders, objects } = currentBucket;

  if (folders.has(currentFolder)) return 'checked';

  // Root directory of bucket case
  if (currentFolder === '/' && (folders.size > 0 || objects.size > 0)) return 'partial';

  // If the folder is contained by a selected folder -> checked
  if (
    getAncestors({ type: 'folder', fullPath: currentFolder }).some((ancestor) =>
      folders.has(ancestor),
    )
  ) {
    return 'checked';
  }

  // At least one item in selection is a child of current folder -> partial
  for (const folder of folders) if (folder.startsWith(currentFolder)) return 'partial';
  for (const object of objects) if (object.startsWith(currentFolder)) return 'partial';

  return 'unchecked';
};

// Logic for determining what state the selection checkbox for item should be
export const checkboxState = (state: SelectedItemsStore, bucketName: string, item: BucketItem) => {
  const currentBucket = state.buckets.find((bucket) => bucket.bucketName === bucketName);
  if (currentBucket === undefined) return 'unchecked';
  const { folders, objects } = currentBucket;

  // Exact folder or item match
  if (folders.has(item.fullPath) || objects.has(item.fullPath)) return 'checked';

  // Item is contained in a selected folder, i.e. are any of it's ancestors included in the selected folders
  if (getAncestors(item).some((ancestor) => folders.has(ancestor))) return 'checked';

  // Item is a folder and some selected objects or folders are contained within it --> partial
  if (item.type === 'folder') {
    for (const folder of folders) if (folder.startsWith(item.fullPath)) return 'partial';
    for (const object of objects) if (object.startsWith(item.fullPath)) return 'partial';
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

// Returns count of all items in the selection store -- the number of selected items
// means selected folders and selected objects, not the total amount of objects contained
// in the selection (i.e., a folder counts as one item, we do not count how many
// children it has -- we may add that in the future).
export const getFullSelectionCount = (buckets: BucketSelection[]) => {
  let count = 0;
  buckets.forEach((bucket) => {
    count += [...bucket.folders].length;
    count += [...bucket.objects].length;
  });
  return count;
};

// Returns count of all items in the selected for a particular bucket -- the number
// of selected items means selected folders and selected objects, not the total amount
// of objects contained in the selection (i.e., a folder counts as one item, we
// do not count how many children it has -- we may add that in the future).
export const getBucketSelectionCount = (bucket: BucketSelection) => {
  let count = 0;
  count += [...bucket.folders].length;
  count += [...bucket.objects].length;
  return count > 1 ? `${count} selections` : `1 selection`;
};

// Format for request body to backend CSV export endpoint
export type SelectionCsvExportBody = {
  bucket: string;
  files: string[];
  directories: string[];
};

// Convert the selection store to the correct data shape for a request to the
// backend CSV export endpoint
export const csvExportReqBody = (buckets: BucketSelection[]): SelectionCsvExportBody[] => {
  return buckets.map((bucket) => {
    return {
      bucket: bucket.bucketName,
      files: [...bucket.objects],
      directories: [...bucket.folders],
    };
  });
};
