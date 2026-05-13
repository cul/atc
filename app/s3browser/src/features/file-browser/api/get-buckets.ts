import { queryOptions, useSuspenseQuery } from '@tanstack/react-query';
// import { api } from '@/lib/api-client';
import { Bucket } from '@/types/api';
import { QueryConfig } from '@/lib/react-query';

const getBuckets = (): Promise<Bucket[]> => {
  // return api.get<Bucket[]>('/buckets'); 

  // Temporary mock implementation until backend is ready
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve([
        { name: 'bucket-1', description: 'd' },
        { name: 'bucket-2', description: 'aa b' },
        { name: 'bucket-3', description: 'zzz' },
      ]);
    }, 500);
  });
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
