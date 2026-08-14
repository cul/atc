import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { Spinner } from 'react-bootstrap';
import { useParams, useSearchParams } from 'react-router';

import { useSelectedItemsStore, useSelectAllCheckboxState } from '@/stores/selected-items-store';
import { getBucketContentsQueryOptions } from '../api/get-bucket-contents';
import { getAncestors, notifySelectionError } from '../utils/selection-utils';

const SelectAllCheckbox = () => {
  const { bucketName } = useParams();
  const [searchParams] = useSearchParams();
  const currentPrefix = searchParams.get('prefix') ?? '/';
  const { selectItem, deselectItem } = useSelectedItemsStore();
  const queryClient = useQueryClient();
  const [pending, setPending] = useState(false);
  const checkedState = useSelectAllCheckboxState(bucketName, currentPrefix);
  const checkboxRef = useRef(null);

  useEffect(() => {
    if (checkboxRef.current) {
      checkboxRef.current.indeterminate = checkedState === 'partial' ? true : false;
    }
  }, [checkboxRef, checkedState, pending]);

  // Clicking the select all checkbox is like you clicked the folder itself
  const executeSelection = (folder: string, checkedState: string) => {
    if (checkedState === 'checked') {
      deselectItem({ type: 'folder', fullPath: folder }, bucketName, queryClient);
    } else {
      selectItem({ type: 'folder', fullPath: folder }, bucketName, queryClient);
    }
  };
  const handleClick = async (folder: string, checkedState: string) => {
    setPending(true);
    // Wait until all of the data we need for selection logic is in the query cache
    // and is fresh before executing the selection logic
    try {
      await Promise.all(
        getAncestors({ type: 'folder', fullPath: folder }).map((ancestorPrefix) =>
          queryClient.fetchQuery({
            ...getBucketContentsQueryOptions(bucketName, ancestorPrefix),
          }),
        ),
      );
      executeSelection(folder, checkedState);
    } catch (error) {
      notifySelectionError(error.message);
    } finally {
      setPending(false);
    }
  };

  return (
    <div className="text-center">
      <span>Selection </span>
      {pending ? (
        <Spinner animation="border" size="sm" variant="primary" />
      ) : (
        <>
          <input
            ref={checkboxRef}
            className="form-check-input"
            type="checkbox"
            checked={checkedState === 'checked'}
            id={`selectAll-${currentPrefix}`}
            onChange={() => handleClick(currentPrefix, checkedState)}
          />
          <label className="form-check-label" htmlFor={`selectAll-${currentPrefix}`} />
        </>
      )}
    </div>
  );
};

export default SelectAllCheckbox;
