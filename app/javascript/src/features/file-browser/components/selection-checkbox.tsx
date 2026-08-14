import { Spinner } from 'react-bootstrap';
import { useEffect, useRef, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { useParams } from 'react-router';
import { Row } from '@tanstack/react-table';

import { getBucketContentsQueryOptions } from '../api/get-bucket-contents';
import { getAncestors, notifySelectionError } from '../utils/selection-utils';
import { BucketItem } from '@/types/api';
import { useCheckboxState, useSelectedItemsStore } from '@/stores/selected-items-store';

const SelectionCheckbox = ({ row }: { row: Row<BucketItem> }) => {
  const { bucketName } = useParams();
  const { selectItem, deselectItem } = useSelectedItemsStore();
  const queryClient = useQueryClient();
  const checkedState = useCheckboxState(bucketName, row.original);
  const [pending, setPending] = useState(false);
  const checkboxRef = useRef(null);

  useEffect(() => {
    if (checkboxRef.current) {
      checkboxRef.current.indeterminate = checkedState === 'partial' ? true : false;
    }
  }, [checkboxRef, checkedState, pending]);

  const executeSelection = (rowItem: BucketItem, checkedState: string) => {
    if (checkedState === 'checked') {
      deselectItem(rowItem, bucketName, queryClient);
    } else {
      // checkedState === 'unchecked' || checkedState ==='partial'
      selectItem(rowItem, bucketName, queryClient);
    }
  };

  const handleClick = async (rowItem: BucketItem, checkedState: string) => {
    setPending(true);
    // Wait until all of the data we need for selection logic is in the query cache
    // and is fresh before executing the selection logic
    try {
      await Promise.all(
        getAncestors(rowItem).map((ancestorPrefix) =>
          queryClient.fetchQuery({
            ...getBucketContentsQueryOptions(bucketName, ancestorPrefix),
          }),
        ),
      );
      executeSelection(rowItem, checkedState);
    } catch (error) {
      notifySelectionError(error.message);
    } finally {
      setPending(false);
    }
  };

  return (
    <div className="text-center">
      {pending ? (
        <Spinner animation="border" size="sm" variant="primary" />
      ) : (
        <>
          <input
            ref={checkboxRef}
            className="form-check-input"
            type="checkbox"
            checked={checkedState === 'checked'}
            id={`checkItem${row.id}`}
            onChange={() => handleClick(row.original, checkedState)}
          />
          <label className="form-check-label" htmlFor={`checkItem${row.id}`} />
        </>
      )}
    </div>
  );
};

export default SelectionCheckbox;
