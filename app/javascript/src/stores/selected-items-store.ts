import { QueryClient } from '@tanstack/react-query';
import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';
import { createJSONStorage, persist } from 'zustand/middleware';
import { enableMapSet } from 'immer';

import {
  checkboxState,
  countSelectedAncestorChildren,
  getAncestors,
  getAncestorsBetween,
  getNearestSelectedParent,
  isAnyChildOf,
  isDirectChildOf,
  selectAllCheckboxState,
} from '@/features/file-browser/utils/selection-utils';
import { BucketContentsResponse, BucketItem } from '@/types/api';

// Enable Sets for immer. Immer only supports add, has, and delete on sets,
// so even with this we can't use unions, intersections, etc.
enableMapSet();

type CheckboxState = 'checked' | 'unchecked' | 'partial';

export const ERRORS = {
  entireBucketSelection:
    "Selecting an entire bucket's contents is not supported. If you would like to request an export of an entire bucket's contents, please contact an administrator.",
};

export type BucketSelection = {
  bucketName: string;
  folders: Set<string>;
  objects: Set<string>;
};

export type SelectedItemsStore = {
  buckets: Array<BucketSelection>;

  selectItem: (
    item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
    currentBucket: string,
    queryClient: QueryClient,
  ) => void;
  deselectItem: (
    item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
    currentBucket: string,
    queryClient: QueryClient,
  ) => void;
  reset: () => void;
};

// This method runs when we add an item to the selection and handles the cases
// where the new selection means we have selected all the contents of a folder.
// It recursively looks at the 'ancestors' of our selection and checks whether
// we can consider that folder to be completely selected. If yes, we remove all
// children of that folder and add the folder to the selection store (repeating
// on the nex layer up, until we can no longer collapse)
const collapseParents = (
  currentBucket: string,
  item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
  queryClient: QueryClient,
  nextFolders: Set<string>,
  nextObjects: Set<string>,
) => {
  const ancestors = getAncestors(item);
  for (const ancestorFolder of ancestors) {
    const ancestorData = queryClient.getQueryData<BucketContentsResponse>([
      'bucket-contents',
      currentBucket,
      ancestorFolder,
    ]);
    const numAncestorChildren = ancestorData.folders.length + ancestorData.objects.length;
    const numSelectedAncestorChildren = countSelectedAncestorChildren(
      nextFolders,
      nextObjects,
      ancestorFolder,
    );
    if (numSelectedAncestorChildren === numAncestorChildren) {
      if (ancestorFolder === '/') {
        throw new Error(ERRORS.entireBucketSelection);
      }
      // We have now selected all at this prefix level, we should remove all selected items at this level
      for (const folder of nextFolders) {
        if (isDirectChildOf(folder, ancestorFolder)) {
          nextFolders.delete(folder);
        }
      }
      for (const object of nextObjects) {
        if (isDirectChildOf(object, ancestorFolder)) {
          nextObjects.delete(object);
        }
      }
      // And add the parent to the selected folders set
      nextFolders.add(ancestorFolder);
    } else {
      // We have collapsed as far as we can - done!
      break;
    }
  }
};

// This function runs when we deselect an item and remove it from the selection.
// If the item we deselected was included in the selection set because it was a
// child of a selected folder, then we can no longer consider the folder to be
// a recursive selection adn need to 'explode' each level of our selection up
// until that containing folder -- exploding means adding all the children
// items individually to the selection store for this bucket
const explodeParents = (
  currentBucket: string,
  item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
  queryClient: QueryClient,
  nextObjects: Set<string>,
  nextFolders: Set<string>,
) => {
  const nearestSelectedParent = getNearestSelectedParent(item.fullPath, nextFolders);
  if (nearestSelectedParent) {
    const ancestorFolders = getAncestorsBetween(item, nearestSelectedParent);
    for (const ancestorFolder of ancestorFolders) {
      const ancestorData = queryClient.getQueryData<BucketContentsResponse>([
        'bucket-contents',
        currentBucket,
        ancestorFolder,
      ]);
      if (nextFolders.has(ancestorFolder)) nextFolders.delete(ancestorFolder);
      // add all items except for the ancestor folder itself and the object itself
      for (const object of ancestorData.objects) {
        if (object.key !== item.fullPath) {
          nextObjects.add(object.key);
        }
      }
      for (const folder of ancestorData.folders) {
        // Do not add a folder if it is part of the ancestor tree itself (that will be a partial selection)
        if (ancestorFolders.includes(folder)) {
          nextFolders.delete(folder);
        } else {
          if (folder !== item.fullPath) nextFolders.add(folder);
        }
      }
    }
  } // else - no parent folder is in the selection
};

// Custom serializer to handle Hash Sets when persisting to local storage
const storage = createJSONStorage(() => localStorage, {
  replacer: (_key, value) => {
    if (value instanceof Set) {
      return [...value];
    }
    return value;
  },
  reviver: (key, value: string) => {
    if (key === 'folders' || key === 'objects') {
      return new Set<string>(value);
    }
    return value;
  },
});

export const useSelectedItemsStore = create<SelectedItemsStore>()(
  persist(
    immer((set) => ({
      buckets: [],
      reset: () => {
        set({ buckets: [] });
      },
      selectItem: (
        item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
        currentBucket: string,
        queryClient: QueryClient,
      ) => {
        set((state) => {
          if (item.fullPath === '/') {
            throw new Error(ERRORS.entireBucketSelection);
          }

          let bucketSelection = state.buckets.find((bucket) => bucket.bucketName === currentBucket);

          // Case: first time making a selection in this bucket
          if (!bucketSelection) {
            state.buckets.push({
              bucketName: currentBucket,
              folders: new Set<string>(),
              objects: new Set<string>(),
            });
            bucketSelection = state.buckets.find((bucket) => bucket.bucketName === currentBucket);
          }

          const nextFolders = bucketSelection.folders;
          const nextObjects = bucketSelection.objects;

          if (item.type === 'object') nextObjects.add(item.fullPath);
          if (item.type === 'folder') {
            // remove any children, then add the folder
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
      deselectItem: (
        item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
        currentBucket: string,
        queryClient: QueryClient,
      ) => {
        set((state) => {
          const bucketSelection = state.buckets.find(
            (bucket) => bucket.bucketName === currentBucket,
          );
          const nextFolders = bucketSelection.folders;
          const nextObjects = bucketSelection.objects;

          if (item.type === 'object') nextObjects.delete(item.fullPath);
          else nextFolders.delete(item.fullPath);

          explodeParents(currentBucket, item, queryClient, nextObjects, nextFolders);

          // Remove any empty buckets
          state.buckets = state.buckets.filter((bucket) => {
            return [...bucket.folders].length > 0 || [...bucket.objects].length > 0;
          });
        });
      },
    })),
    {
      name: 'AtcS3BrowserSelectedItems',
      storage: storage,
    },
  ),
);

// Determine the state of a select all checkbox in a bucket-contents table
export const useSelectAllCheckboxState = (
  bucketName: string,
  currentFolder: string,
): CheckboxState => {
  return useSelectedItemsStore((state) => selectAllCheckboxState(state, bucketName, currentFolder));
};

// Determine the checked state of an item checkbox in a row of a bucket-contents table.
export const useCheckboxState = (bucketName: string, item: BucketItem): CheckboxState => {
  return useSelectedItemsStore((state) => checkboxState(state, bucketName, item));
};
