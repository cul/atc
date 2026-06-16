import { ColumnDef } from '@tanstack/react-table';
import { useBucketsSuspenseQuery } from '../api/get-buckets';
import { columnDefs } from '../utils/bucket-list-column-defs';
import { Bucket } from '@/types/api';
import TableBuilder from '@/components/ui/table-builder/table-builder';

const BucketList = () => {
  const getBucketsQuery = useBucketsSuspenseQuery();
  const buckets = getBucketsQuery.data.buckets;

  if (!buckets || buckets.length === 0) {
    return <p>No buckets found.</p>;
  }

  return (
    <div>
      <h1>S3 Buckets</h1>
      <TableBuilder
        data={buckets}
        columns={columnDefs as ColumnDef<Bucket>[]}
        initialSorting={[{ id: 'name', desc: false }]}
      />
    </div>
  );
};

export default BucketList;
