import { getAncestors, getAncestorsBetween } from '@/features/file-browser/utils/selection-utils';
import { Bucket, BucketContentsResponse, BucketItem } from '@/types/api';
import { QueryClient } from '@tanstack/react-query';
import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';
import { enableMapSet, current } from 'immer';
import BucketsRoute from '@/app/routes/buckets';

// Immer only supports add, has, and delete on sets, so we can't use unions, etc.
enableMapSet();

type BucketSelection = {
  bucketName: string;
  folders: Set<string>;
  objects: Set<string>;
};

// TODO: add cross bucket selection
type SelectedItemsStore = {
  buckets: Array<BucketSelection>;
  selectItem: (item: BucketItem, currentBucket: string, queryClient: QueryClient) => void;
  deselectItem: (item: BucketItem, currentBucket: string, queryClient: QueryClient) => void;
  reset: () => void;
};

const subtractPrefix = (path: string, prefix: string) => path.replace(prefix, '');

const isDirectChildOf = (path: string, prefix: string) => {
  if (path.endsWith('/')) path = path.slice(0, -1); // Remove trailing / for folders
  // Base case: top level of a bucket
  if (prefix === '/') {
    return !path.includes('/');
  }
  return path.startsWith(prefix) && !subtractPrefix(path, prefix).includes('/');
};

const countSelectedAncestorChildren = (
  nextFolders: Set<string>,
  nextObjects: Set<string>,
  prefix: string,
) => {
  let count = 0;
  for (const path of nextFolders) if (isDirectChildOf(path, prefix)) count++;
  for (const path of nextObjects) if (isDirectChildOf(path, prefix)) count++;
  return count;
};

const collapseParents = (
  currentBucket: string,
  item: BucketItem,
  queryClient: QueryClient,
  nextFolders: Set<string>,
  nextObjects: Set<string>,
) => {
  const ancestors = getAncestors(item);
  console.log('selected item ancestors');
  console.log(ancestors);
  console.log('looping:');

  // If the selected item fills up the current level, then we should:
  // - remove all other items at this level from the store
  // - add the parent to the store as a folder
  // ancestors.forEach((ancestorPrefix) => {
  for (const ancestorPrefix of ancestors) {
    const ancestorData = queryClient.getQueryData<BucketContentsResponse>([
      'bucket-contents',
      currentBucket, // TODO account for cross bucket selections
      ancestorPrefix,
    ]);
    console.log('  data for ' + ancestorPrefix);
    console.log(ancestorData);
    const numAncestorChildren = ancestorData.folders.length + ancestorData.objects.length;
    const numSelectedAncestorChildren = countSelectedAncestorChildren(
      nextFolders,
      nextObjects,
      ancestorPrefix,
    );
    console.log(
      `  num selected ancestor children: ${ancestorPrefix} has ${numSelectedAncestorChildren}`,
    );
    console.log(`  num data ancestor children: ${ancestorPrefix} has ${numAncestorChildren}`);
    if (numSelectedAncestorChildren === numAncestorChildren) {
      console.log(
        `  we have selected all ${numSelectedAncestorChildren} of ${numAncestorChildren}`,
      );
      // We have now selected all at this prefix level, we should remove all selected items at this level
      for (const folder of nextFolders) {
        if (isDirectChildOf(folder, ancestorPrefix)) {
          nextFolders.delete(folder);
        }
      }
      for (const object of nextObjects) {
        if (isDirectChildOf(object, ancestorPrefix)) {
          nextObjects.delete(object);
        }
      }
      // And add the parent to the selected folders set
      nextFolders.add(ancestorPrefix);
    } else {
      // We have collapsed as far as we can
      break;
    }
  }
  console.log('----------- selection added -----');
};

const isAnyChildOf = (path: string, prefix: string) => path.startsWith(prefix);

// TODO : change prefix to folders if we can! more consistent naming.

const getNearestSelectedParent = (path: string, folders: Set<string>) => {
  for (const folder of folders) {
    if (path.includes(folder)) return folder;
  }
};

const explodeParents = (
  currentBucket: string,
  item: BucketItem,
  queryClient: QueryClient,
  nextObjects: Set<string>,
  nextFolders: Set<string>,
) => {
  console.log('explodeParents entry');
  const nearestSelectedParent = getNearestSelectedParent(item.fullPath, nextFolders);
  console.log('nearest parent is ' + nearestSelectedParent);
  if (nearestSelectedParent) {
    // explode recursively up
    const ancestorFolders = getAncestorsBetween(item, nearestSelectedParent);
    console.log('ancestors between:');
    console.log(ancestorFolders);
    for (const ancestorFolder of ancestorFolders) {
      console.log('querying for:');
      console.log([
        'bucket-contents',
        currentBucket, // TODO account for cross bucket selections
        ancestorFolder,
      ]);
      const ancestorData = queryClient.getQueryData<BucketContentsResponse>([
        'bucket-contents',
        currentBucket, // TODO account for cross bucket selections
        ancestorFolder,
      ]);
      console.log('      ancestorFolder: ' + ancestorFolder);
      console.log('      ancestor data:');
      console.log(ancestorData);
      if (nextFolders.has(ancestorFolder)) nextFolders.delete(ancestorFolder);
      // add all items except for the ancestor folder itself and the object itself...
      for (const object of ancestorData.objects) {
        if (object.key !== item.fullPath) {
          console.log('adding object');
          nextObjects.add(object.key);
        }
      }
      for (const folder of ancestorData.folders) {
        // Do not add a folder if it is part of the ancestor tree itself (that will be a partial selection)
        if (ancestorFolders.includes(folder)) {
          console.log('removing folder');
          nextFolders.delete(folder);
        } else {
          console.log('adding folder');
          if (folder !== item.fullPath) nextFolders.add(folder);
        }
      }
    }
  } else {
    console.log('no nearest parent');
  }

  console.log('--------- done with deselect');
};

export const useSelectedItemsStore = create<SelectedItemsStore>()(
  immer((set) => ({
    buckets: [],
    reset: () => {
      console.log('resetting selection');
      set({ buckets: [] });
      // set({ folders: new Set<string>(), objects: new Set<string>() });
    },
    selectItem: (item: BucketItem, currentBucket: string, queryClient: QueryClient) => {
      set((state) => {
        console.log('------   select item ------- ');
        let bucketSelection = state.buckets.find((bucket) => bucket.bucketName === currentBucket);
        console.log('current state:');
        console.log(current(state));

        // Base case: first selection
        if (!bucketSelection) {
          state.buckets.push({
            bucketName: currentBucket,
            folders: new Set<string>(),
            objects: new Set<string>(),
          });
          console.log('creating bucket selection!');
          bucketSelection = state.buckets.find((bucket) => bucket.bucketName === currentBucket);
        }

        const nextFolders = bucketSelection.folders;
        console.log('set');
        const nextObjects = bucketSelection.objects;

        // TODO : YOU ARE HERE! :)

        console.log('here1');
        if (item.type === 'object') nextObjects.add(item.fullPath);
        if (item.type === 'folder') {
          // remove any children, then add folder
          for (const path of nextFolders) {
            if (isAnyChildOf(path, item.fullPath)) {
              nextFolders.delete(path);
            }
          }
          for (const path of nextObjects) {
            if (isAnyChildOf(path, item.fullPath)) {
              nextObjects.delete(path);
            }
          }
          nextFolders.add(item.fullPath);
        }

        collapseParents(currentBucket, item, queryClient, nextFolders, nextObjects);
      });
    },
    deselectItem: (item: BucketItem, currentBucket: string, queryClient: QueryClient) => {
      console.log('--------- deselecting item');

      set((state) => {
        let bucketSelection = state.buckets.find((bucket) => bucket.bucketName === currentBucket);
        console.log('current selected bucket');
        console.log(current(state));
        const nextFolders = bucketSelection.folders;
        const nextObjects = bucketSelection.objects;
        console.log('huh');
        item.type === 'object'
          ? nextObjects.delete(item.fullPath)
          : nextFolders.delete(item.fullPath);

        console.log('what');
        explodeParents(currentBucket, item, queryClient, nextObjects, nextFolders);
      });
    },
  })),
);

type CheckboxState = 'checked' | 'unchecked' | 'partial';

export const useCheckboxState = (bucketName: string, item: BucketItem): CheckboxState => {
  return useSelectedItemsStore((state) => {
    const currentBucket = state.buckets.find((bucket) => bucket.bucketName === bucketName);
    if (currentBucket === undefined) return 'unchecked';
    const { folders, objects } = currentBucket;

    // exact folder or item match
    if (folders.has(item.fullPath) || objects.has(item.fullPath)) return 'checked';

    // item is contained in a selected folder -> are any of it's ancestors included in the selected folders
    if (getAncestors(item).some((ancestor) => folders.has(ancestor))) return 'checked';

    // item is a folder and some selected objects or folders are contained within it --> partial
    if (item.type === 'folder') {
      for (let folder of folders) if (folder.startsWith(item.fullPath)) return 'partial';
      for (let object of objects) if (object.startsWith(item.fullPath)) return 'partial';
    }

    return 'unchecked';
  });
};
