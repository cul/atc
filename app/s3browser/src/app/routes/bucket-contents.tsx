import { QueryClient } from '@tanstack/react-query';
import { LoaderFunctionArgs } from 'react-router';
import { getBucketContentsQueryOptions } from '@/features/file-browser/api/get-bucket-contents';
import BucketContentsTable from '@/features/file-browser/components/bucket-contents-table';

// Prefix has to end with '/' for S3 ListObjectsV2 to treat it as a folder
const normalizePrefix = (raw: string): string => {
  if (!raw) return '';
  return raw.endsWith('/') ? raw : `${raw}/`;
};

export const clientLoader = (queryClient: QueryClient) => async ({ params, request }: LoaderFunctionArgs) => {
  const bucketName = params.bucketName as string;
  const url = new URL(request.url);
  const prefix = normalizePrefix(url.searchParams.get('prefix') ?? '');
  const query = getBucketContentsQueryOptions(bucketName, prefix);

  console.log('Loading bucket contents for', bucketName, 'with prefix', prefix);

  queryClient.prefetchQuery(query);
};

const BucketContentsRoute = () => {
  return <BucketContentsTable />;
};

export default BucketContentsRoute;