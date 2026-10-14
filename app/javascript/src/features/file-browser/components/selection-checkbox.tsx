import { useParams } from 'react-router';
import { Row } from '@tanstack/react-table';

import { BucketItem } from '@/types/api';
import { useCheckboxState } from '@/stores/selected-items-store';
import useSelectionCheckbox from '../hooks/use-selection-checkbox';
import { SelectionCheckboxInput } from './selection-checkbox-input';

const SelectionCheckbox = ({ row }: { row: Row<BucketItem> }) => {
  const { bucketName } = useParams();
  const checkedState = useCheckboxState(bucketName, row.original);
  const { pending, checkboxRef, handleClick } = useSelectionCheckbox(
    row.original,
    checkedState,
    bucketName,
  );

  return (
    <div className="text-center">
      <SelectionCheckboxInput
        id={`checkItem${row.id}`}
        checked={checkedState === 'checked'}
        pending={pending}
        checkboxRef={checkboxRef}
        onChange={handleClick}
      />
    </div>
  );
};

export default SelectionCheckbox;
