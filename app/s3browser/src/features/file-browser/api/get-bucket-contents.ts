import { queryOptions, useQuery } from '@tanstack/react-query';
import { BucketContentsResponse } from '@/types/api';
import { api } from '@/lib/api-client';
import { QueryConfig } from '@/lib/react-query';

const getBucketContents = (
  bucket: string,
  prefix: string,
): Promise<BucketContentsResponse> => {
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


export const useBucketContentsQuery = ({ bucket, prefix, queryConfig }: UseBucketContentsOptions) => {
  return useQuery({
    ...getBucketContentsQueryOptions(bucket, prefix),
    ...queryConfig,
  });
};
