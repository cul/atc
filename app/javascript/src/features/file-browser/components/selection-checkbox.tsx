import { Spinner } from 'react-bootstrap';
import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { useParams } from 'react-router';
import { Row } from '@tanstack/react-table';

import { getBucketContentsQueryOptions } from '../api/get-bucket-contents';
import { getAncestors } from '../utils/selection-utils';
import { BucketItem } from '@/types/api';
import { useCheckboxState, useSelectedItemsStore } from '@/stores/selected-items-store';

// non modifiable checkbox for folder selection's children
// then we only track exactly what the user does and only correct indeterminate check to full check when they manually check it off

const SelectionCheckbox = ({ row }: { row: Row<BucketItem> }) => {
  const { bucketName } = useParams();
  const { selectItem, deselectItem } = useSelectedItemsStore();
  const queryClient = useQueryClient();
  const checkedState = useCheckboxState(bucketName, row.original);
  const [pending, setPending] = useState(false);

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
        className="form-check-input"
        type="checkbox"
        checked={checkedState === 'checked'}
        id={`checkItem${row.id}`}
        onChange={() => handleClick(row.original, checkedState)}
      ></input>
      {checkedState}
      <label className="form-check-label" htmlFor={`checkItem${row.id}`} />
    </div>
  );
};

export default SelectionCheckbox;
