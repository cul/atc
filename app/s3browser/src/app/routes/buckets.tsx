import { QueryClient } from '@tanstack/react-query';
import { getBucketsQueryOptions } from '@/features/file-browser/api/get-buckets';
import BucketList from '@/features/file-browser/components/bucket-list';

export const clientLoader = (queryClient: QueryClient) => async () => {
  const query = getBucketsQueryOptions();

  return await queryClient.ensureQueryData(query);
};

const BucketsRoute = () => {
  return <BucketList />;
};

export default BucketsRoute;