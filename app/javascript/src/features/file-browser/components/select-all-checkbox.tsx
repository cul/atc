import { useParams, useSearchParams } from 'react-router';

import { useCheckboxState } from '@/stores/selected-items-store';
import { BucketItem } from '@/types/api';
import useSelectionCheckbox from '../hooks/use-selection-checkbox';
import { SelectionCheckboxInput } from './selection-checkbox-input';

const SelectAllCheckbox = () => {
  const { bucketName } = useParams();
  const [searchParams] = useSearchParams();
  const currentPrefix = searchParams.get('prefix') ?? '/';
  const checkedState = useCheckboxState(bucketName, {
    type: 'folder',
    fullPath: currentPrefix,
  } as BucketItem);
  const { pending, checkboxRef, handleClick } = useSelectionCheckbox(
    {
      type: 'folder',
      fullPath: currentPrefix,
    } as BucketItem,
    checkedState,
    bucketName,
  );
  return (
    <div className="text-center">
      <span>Selection </span>
      <SelectionCheckboxInput
        id={`selectall-${currentPrefix}`}
        checked={checkedState === 'checked'}
        pending={pending}
        checkboxRef={checkboxRef}
        onChange={handleClick}
      />
    </div>
  );
};

export default SelectAllCheckbox;
