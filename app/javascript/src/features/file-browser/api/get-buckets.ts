import { queryOptions, useSuspenseQuery } from '@tanstack/react-query';
import { api } from '@/lib/api-client';
import { Bucket } from '@/types/api';
import { QueryConfig } from '@/lib/react-query';

const getBuckets = async (): Promise<{ buckets: Bucket[] }> => {
  return api.get<{ buckets: Bucket[] }>('/buckets');
};

export const getBucketsQueryOptions = () => {
  return queryOptions({
    queryKey: ['buckets'],
    queryFn: getBuckets,
  });
};

type UseBucketsOptions = {
  queryConfig?: QueryConfig<typeof getBucketsQueryOptions>;
};

export const useBucketsSuspenseQuery = ({ queryConfig }: UseBucketsOptions = {}) => {
  return useSuspenseQuery({
    ...getBucketsQueryOptions(),
    ...queryConfig,
  });
};
