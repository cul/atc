import { Link } from 'react-router';
import { useBucketsSuspenseQuery } from '../api/get-buckets';

const BucketList = () => {
  const getBucketsQuery = useBucketsSuspenseQuery();
  const buckets = getBucketsQuery.data;

  if (!buckets || buckets.length === 0) {
    return <p>No buckets found.</p>;
  }

  return (
    <div>
      <h1>S3 Buckets</h1>
      {/* Temporarily use a table element instead of TanStack Table */}
      <table className="table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Description</th>
          </tr>
        </thead>
        <tbody>
          {buckets.map((bucket) => (
            <tr key={bucket.name}>
              <td>
                <Link to={`/bucket/${encodeURIComponent(bucket.name)}`}>
                  {bucket.name}
                </Link>
              </td>
              <td>{bucket.description}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default BucketList;