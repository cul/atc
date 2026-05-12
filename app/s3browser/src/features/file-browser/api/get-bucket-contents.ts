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
  const endpoint = `/buckets/${bucket}${query ? `?${query}` : ''}`;

  
  console.log('Fetching bucket contents for:', bucket, 'with prefix:', prefix);
  
  // Temporarily return a mock response until we implement the backend API
  return Promise.resolve({
    folders: [
      prefix,
      "example/prefix/path/folder1/",
      "example/prefix/path/folder2/",
    ],
    objects: [
      {
        key: `${prefix}abc.txt`,
        size: 1234,
        lastModified: new Date().toISOString(),
        storageClass: 'STANDARD',
      },
      {
        key: `${prefix}xyz.txt`,
        size: 5678,
        lastModified: new Date().toISOString(),
        storageClass: 'INTELLIGENT_TIERING'
      },
    ],
  });

  // return api.get<BucketContentsResponse>(endpoint);
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
