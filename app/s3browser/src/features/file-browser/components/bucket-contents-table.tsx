import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { columnDefs } from '../utils/bucket-contents-column-defs';
import { toBucketItems } from '../utils/transform-to-bucket-items';
import { Link, useParams, useSearchParams } from 'react-router';
import { useBucketContentsQuery } from '@/features/file-browser/api/get-bucket-contents';
import TableBuilder from '@/components/ui/table-builder/table-builder';

const normalizePrefix = (raw: string): string => {
  if (!raw) return '';
  return raw.endsWith('/') ? raw : `${raw}/`;
};

const BucketContentsTable = () => {
  const { bucketName } = useParams();
  const [searchParams] = useSearchParams();
  const bucket = bucketName as string;
  const prefix = normalizePrefix(searchParams.get('prefix') ?? '');

  const bucketPath = `/bucket/${encodeURIComponent(bucket)}`;

  const { data } = useBucketContentsQuery({ bucket, prefix });

  console.log('BucketContents query data', data);

  // Transform the split API response into a flat array for TanStack Table.
  // Reruns whenever the raw API response changes, but not on every render.
  const items = useMemo(() => {
    if (!data) return [];
    return toBucketItems(data);
  }, [data]);

  return (
    <div>
      Bucket contents for <strong>{bucket}</strong> with prefix <strong>{prefix}</strong>

      <TableBuilder data={items} columns={columnDefs} />
    </div>
  );
};

export default BucketContentsTable;