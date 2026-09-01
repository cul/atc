import { QueryClient, queryOptions, useQueries, useQuery } from '@tanstack/react-query';
import { BucketContentsResponse } from '@/types/api';
import { api } from '@/lib/api-client';
import { QueryConfig } from '@/lib/react-query';

const getBucketContents = (bucket: string, prefix: string): Promise<BucketContentsResponse> => {
  const params = new URLSearchParams();
  if (prefix) {
    params.set('prefix', prefix);
  }

  const query = params.toString();
  const endpoint = `/buckets/${bucket}/list${query ? `?${query}` : ''}`;

  return api.get<BucketContentsResponse>(endpoint);
};

type UseBucketContentsOptions = {
  bucket: string;
  prefix: string;
  queryConfig?: QueryConfig<typeof getBucketContentsQueryOptions>;
};

export const getBucketContentsQueryOptions = (bucket: string, prefix: string) => {
  return queryOptions({
    queryKey: ['bucket-contents', bucket, prefix],
    queryFn: () => getBucketContents(bucket, prefix),
  });
};

export const getCachedBucketContents = (
  queryClient: QueryClient,
  bucket: string,
  prefix: string,
): BucketContentsResponse | undefined => {
  return queryClient.getQueryData(getBucketContentsQueryOptions(bucket, prefix).queryKey);
};

export const useBucketContentsQuery = ({
  bucket,
  prefix,
  queryConfig,
}: UseBucketContentsOptions) => {
  return useQuery({
    ...getBucketContentsQueryOptions(bucket, prefix),
    ...queryConfig,
  });
};

export const useBucketContentsQueries = (queryArgs: UseBucketContentsOptions[]) => {
  return useQueries({
    queries: queryArgs.map((args) => {
      return {
        ...getBucketContentsQueryOptions(args.bucket, args.prefix),
        ...args.queryConfig,
      };
    }),
  });
};
