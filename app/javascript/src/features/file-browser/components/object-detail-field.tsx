import { ReactNode } from 'react';

type ObjectDetailFieldProps = {
  label: string;
  value: ReactNode;
  hint?: string;
};

const ObjectDetailField = ({ label, value, hint }: ObjectDetailFieldProps) => (
  <div className="mb-3">
    <dt className="fw-semibold text-secondary small text-uppercase mb-1">{label}</dt>
    <dd className="mb-0">
      {value}
      {hint && <small className="d-block text-muted mt-1">{hint}</small>}
    </dd>
  </div>
);

export default ObjectDetailField;
