import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { Spinner } from 'react-bootstrap';
import { useParams, useSearchParams } from 'react-router';

import { useSelectedItemsStore, useSelectAllCheckboxState } from '@/stores/selected-items-store';
import { getBucketContentsQueryOptions } from '../api/get-bucket-contents';
import { getAncestors } from '../utils/selection-utils';

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
    checkboxRef.current.indeterminate = checkedState === 'partial' ? true : false;
  }, [checkboxRef, checkedState]);

  // Clicking the select all checkbox is like you clicked the folder itself
  const executeSelection = (folder: string, checkedState: string) => {
    if (checkedState === 'checked') {
      if (bucketName === folder) folder = '/';
      deselectItem({ type: 'folder', fullPath: folder }, bucketName, queryClient);
    } else {
      if (bucketName === folder) folder = '/';
      selectItem({ type: 'folder', fullPath: folder }, bucketName, queryClient);
    }
  };
  const handleClick = async (folder: string, checkedState: string) => {
    const rowItem = { type: 'folder', fullPath: folder };
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
    } catch {
      // TODO: render error notification
    } finally {
      setPending(false);
    }
  };

  if (pending) return <Spinner animation="border" size="sm" variant="primary" />;

  return (
    <div className="text-center">
      <input
        ref={checkboxRef}
        className="form-check-input"
        type="checkbox"
        checked={checkedState === 'checked'}
        id={`selectAll-${currentPrefix}`}
        onChange={() => handleClick(currentPrefix, checkedState)}
      />
      <label className="form-check-label" htmlFor={`selectAll-${currentPrefix}`} />
    </div>
  );
};

export default SelectAllCheckbox;
