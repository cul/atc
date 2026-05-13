import { useNavigate } from 'react-router';
import { useBucketsSuspenseQuery } from '../api/get-buckets';
import TableBuilder from '@/components/ui/table-builder/table-builder';
import { columnDefs } from '../utils/bucket-list-column-defs';

const BucketList = () => {
  const getBucketsQuery = useBucketsSuspenseQuery();
  const buckets = getBucketsQuery.data;
  const navigate = useNavigate();

  if (!buckets || buckets.length === 0) {
    return <p>No buckets found.</p>;
  }

  return (
    <div>
      <h1>S3 Buckets</h1>
      {/* Temp test - navigate to a deeply nested folder */}
      <button onClick={() => navigate('/buckets/bucket-2?prefix=subdirectory/nested_dir/another_dir')}>Navigate to subdirectory</button>
      <TableBuilder data={buckets} columns={columnDefs} initialSorting={[{ id: 'name', desc: false }]}/>
    </div>
  );
};

export default BucketList;