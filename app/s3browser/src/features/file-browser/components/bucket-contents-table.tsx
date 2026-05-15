import { useMemo } from 'react';
import { useParams, useSearchParams } from 'react-router';
import { columnDefs } from '../utils/bucket-contents-column-defs';
import { toBucketItems } from '../utils/transform-to-bucket-items';
import { useBucketContentsQuery } from '../api/get-bucket-contents';
import TableBuilder from '@/components/ui/table-builder/table-builder';

const normalizePrefix = (raw: string): string => {
  if (!raw) return '';
  return raw.endsWith('/') ? raw : `${raw}/`;
};

const BucketContentsTable = () => {
  const { bucketName } = useParams();
  const [searchParams] = useSearchParams();
  const prefix = normalizePrefix(searchParams.get('prefix') ?? '');
  const currentDirectory = prefix ? prefix.split('/').filter(Boolean).pop() : bucketName;

  const { data } = useBucketContentsQuery({ bucket: bucketName, prefix });

  // Transform the split API response into a flat array for TanStack Table.
  // Reruns whenever the raw API response changes, but not on every render.
  const items = useMemo(() => {
    if (!data) return [];
    return toBucketItems(data);
  }, [data]);

  // Column defs depend on bucketName for building folder and file links.
  // Recomputes only when the bucketName changes.
  const columns = useMemo(() => columnDefs(bucketName), [bucketName]);

  return (
    <div>
      <h4><strong>{currentDirectory}/</strong></h4>

      <TableBuilder
        data={items}
        columns={columns}
        initialSorting={[{ id: 'name', desc: false }]}
      />
    </div>
  );
};

export default BucketContentsTable;