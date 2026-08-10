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

export const subtractPrefix = (path: string, prefix: string) => path.replace(prefix, '');

export const isDirectChildOf = (path: string, prefix: string) => {
  if (path.endsWith('/')) path = path.slice(0, -1); // Remove trailing / for folders
  // Base case: top level of a bucket
  if (prefix === '/') {
    return !path.includes('/');
  }
  return path.startsWith(prefix) && !subtractPrefix(path, prefix).includes('/');
};

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
    if (path.includes(folder)) return folder;
  }
  // base case: the nearest selected parent is the entire bucket
  if (folders.has('/')) return '/';
};
