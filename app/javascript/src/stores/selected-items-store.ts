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
} from '@/features/file-browser/utils/selection-utils';
import { BucketContentsResponse, BucketItem } from '@/types/api';

// Enable Sets for immer. Immer only supports add, has, and delete on sets,
// so even with this we can't use unions, intersections, etc.
enableMapSet();

export type CheckboxState = 'checked' | 'unchecked' | 'partial';

export const ERRORS = {
  entireBucketSelection:
    "Selecting an entire bucket's contents is not supported. If you would like to request an export of an entire bucket's contents, please contact an administrator.",
};

export type BucketSelection = {
  bucketName: string;
  folders: Set<string>;
  files: Set<string>;
};

export type SelectedItemsStore = {
  buckets: Array<BucketSelection>;

  selectItem: (
    item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
    currentBucket: string,
    getFolderContents: (prefix: string) => BucketContentsResponse | undefined,
  ) => void;
  deselectItem: (
    item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
    currentBucket: string,
    getFolderContents: (prefix: string) => BucketContentsResponse | undefined,
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
  item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
  nextFolders: Set<string>,
  nextFiles: Set<string>,
  getFolderContents: (prefix: string) => BucketContentsResponse | undefined,
) => {
  const ancestors = getAncestors(item);
  for (const ancestorFolder of ancestors) {
    const ancestorData = getFolderContents(ancestorFolder);
    const numAncestorChildren = ancestorData.folders.length + ancestorData.files.length;
    const numSelectedAncestorChildren = countSelectedAncestorChildren(
      nextFolders,
      nextFiles,
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
      for (const file of nextFiles) {
        if (isDirectChildOf(file, ancestorFolder)) {
          nextFiles.delete(file);
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
  item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
  nextFiles: Set<string>,
  nextFolders: Set<string>,
  getFolderContents: (prefix: string) => BucketContentsResponse | undefined,
) => {
  const nearestSelectedParent = getNearestSelectedParent(item.fullPath, nextFolders);
  if (nearestSelectedParent) {
    const ancestorFolders = getAncestorsBetween(item, nearestSelectedParent);
    for (const ancestorFolder of ancestorFolders) {
      const ancestorData = getFolderContents(ancestorFolder);
      if (nextFolders.has(ancestorFolder)) nextFolders.delete(ancestorFolder);
      // add all items except for the ancestor folder itself and the file itself
      for (const file of ancestorData.files) {
        if (file.key !== item.fullPath) {
          nextFiles.add(file.key);
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
    if (key === 'folders' || key === 'files') {
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
        getFolderContents: (prefix: string) => BucketContentsResponse | undefined,
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
              files: new Set<string>(),
            });
            bucketSelection = state.buckets.find((bucket) => bucket.bucketName === currentBucket);
          }

          const nextFolders = bucketSelection.folders;
          const nextFiles = bucketSelection.files;

          if (item.type === 'object') nextFiles.add(item.fullPath);
          if (item.type === 'folder') {
            // remove any children, then add the folder
            for (const path of nextFolders) {
              if (isAnyChildOf(path, item.fullPath)) {
                nextFolders.delete(path);
              }
            }
            for (const path of nextFiles) {
              if (isAnyChildOf(path, item.fullPath)) {
                nextFiles.delete(path);
              }
            }
            nextFolders.add(item.fullPath);
          }

          collapseParents(item, nextFolders, nextFiles, getFolderContents);
        });
      },
      deselectItem: (
        item: BucketItem | Pick<BucketItem, 'type' | 'fullPath'>,
        currentBucket: string,
        getFolderContents: (prefix: string) => BucketContentsResponse | undefined,
      ) => {
        set((state) => {
          const bucketSelection = state.buckets.find(
            (bucket) => bucket.bucketName === currentBucket,
          );
          const nextFolders = bucketSelection.folders;
          const nextFiles = bucketSelection.files;

          if (item.type === 'object') nextFiles.delete(item.fullPath);
          else nextFolders.delete(item.fullPath);

          explodeParents(item, nextFiles, nextFolders, getFolderContents);

          // Remove any empty buckets
          state.buckets = state.buckets.filter((bucket) => {
            return [...bucket.folders].length > 0 || [...bucket.files].length > 0;
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

export const useCheckboxState = (bucketName: string, item: BucketItem): CheckboxState => {
  return useSelectedItemsStore((state) => {
    const currentBucket = state.buckets.find((bucket) => bucket.bucketName === bucketName);
    return checkboxState(currentBucket, item);
  });
};
