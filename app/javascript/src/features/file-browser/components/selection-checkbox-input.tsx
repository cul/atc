import { RefObject } from 'react';
import { Spinner } from 'react-bootstrap';

interface SelectionCheckboxInputProps {
  id: string;
  checked: boolean;
  pending: boolean;
  checkboxRef: RefObject<HTMLInputElement>;
  onChange: () => void;
}

export const SelectionCheckboxInput = ({
  id,
  checked,
  pending,
  checkboxRef,
  onChange,
}: SelectionCheckboxInputProps) =>
  pending ? (
    <Spinner animation="border" size="sm" variant="primary" />
  ) : (
    <>
      <input
        ref={checkboxRef}
        className="form-check-input"
        type="checkbox"
        checked={checked}
        id={id}
        onChange={onChange}
      />
      <label className="form-check-label" htmlFor={id} />
    </>
  );
