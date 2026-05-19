import { queryOptions, useSuspenseQuery } from '@tanstack/react-query';
import { ObjectDetails } from '@/types/api';
import { api } from '@/lib/api-client';
import { QueryConfig } from '@/lib/react-query';

const getObjectDetails = (
  bucket: string,
  key: string,
): Promise<ObjectDetails> => {
  const params = new URLSearchParams();
  if (key) {
    params.set('key', key);
  }

  const query = params.toString();
  const endpoint = `/buckets/${bucket}/object${query ? `?${query}` : ''}`;

  return api.get<ObjectDetails>(endpoint);
};

type UseObjectDetailsOptions = {
  bucket: string;
  key: string;
  queryConfig?: QueryConfig<typeof getObjectDetailsQueryOptions>;
};

export const getObjectDetailsQueryOptions = (bucket: string, key: string) => {
  return queryOptions({
    queryKey: ['object-details', bucket, key],
    queryFn: () => getObjectDetails(bucket, key),
  });
};


export const useObjectDetailsSuspenseQuery = ({ bucket, key, queryConfig }: UseObjectDetailsOptions) => {
  return useSuspenseQuery({
    ...getObjectDetailsQueryOptions(bucket, key),
    ...queryConfig,
  });
};
