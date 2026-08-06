import { BucketItem } from '@/types/api';

// Returns an array of the current folder or object's ancestors in order of
// closest to furthest (highest)
// e.g. 'a/b/c/d/' -> [ 'a/b/c/', 'a/b/', 'a/', '/' ]
export const getAncestors = (
  item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
): Array<string> => {
  const ancestors = [];
  let path = item.fullPath;
  // Do not include the current item itself if it is a folder
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
export const getAncestorsBetween = (item: BucketItem, cap: string) => {
  const ancestors = [];
  let path = item.fullPath;
  // Do not include the current item itself if it is a folder
  if (item.type === 'folder') path = path.substring(0, path.lastIndexOf('/'));
  while (`${path}/` !== cap) {
    const nextAncestor = path.substring(0, path.lastIndexOf('/'));
    ancestors.push(`${nextAncestor}/`);
    path = nextAncestor;
  }
  return ancestors;
};
