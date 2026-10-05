import { ReactNode } from 'react';

type DetailFieldProps = {
  label: string;
  value: ReactNode;
  hint?: string;
};

const DetailField = ({ label, value, hint }: DetailFieldProps) => (
  <div className="mb-3">
    <dt className="fw-semibold text-secondary small text-uppercase mb-1">{label}</dt>
    <dd className="mb-0">
      {value}
      {hint && <small className="d-block text-muted mt-1">{hint}</small>}
    </dd>
  </div>
);

export default DetailField;
