import { useSelectedItemsStore } from '@/stores/selected-items-store';
import { BucketItem } from '@/types/api';
import { useQueryClient } from '@tanstack/react-query';
import { useState, useRef, useEffect } from 'react';

import { getBucketContentsQueryOptions } from '../api/get-bucket-contents';
import { getAncestors, notifySelectionError } from '../utils/selection-utils';

function useSelectionCheckbox(item: BucketItem, checkedState: string, bucketName: string) {
  const { selectItem, deselectItem } = useSelectedItemsStore();
  const queryClient = useQueryClient();
  const [pending, setPending] = useState(false);
  const checkboxRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (checkboxRef.current) {
      checkboxRef.current.indeterminate = checkedState === 'partial';
    }
  }, [checkedState, pending]);

  const executeSelection = () => {
    if (checkedState === 'checked') {
      deselectItem(item, bucketName, queryClient);
    } else {
      selectItem(item, bucketName, queryClient);
    }
  };

  const handleClick = async () => {
    setPending(true);
    try {
      await Promise.all(
        getAncestors(item).map((ancestorPrefix) =>
          queryClient.fetchQuery({
            ...getBucketContentsQueryOptions(bucketName, ancestorPrefix),
          }),
        ),
      );
      executeSelection();
    } catch (error) {
      notifySelectionError(error.message);
    } finally {
      setPending(false);
    }
  };

  return { pending, checkboxRef, handleClick };
}

export default useSelectionCheckbox;
