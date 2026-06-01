import { QueryClient } from '@tanstack/react-query';
import { LoaderFunctionArgs, useParams } from 'react-router';
import { getBucketContentsQueryOptions } from '@/features/file-browser/api/get-bucket-contents';
import BucketContentsTable from '@/features/file-browser/components/bucket-contents-table';
import { normalizePrefix } from '@/features/file-browser/utils/format-utils';

export const clientLoader = (queryClient: QueryClient) => async ({ params, request }: LoaderFunctionArgs) => {
  const bucketName = params.bucketName as string;
  const url = new URL(request.url);
  const prefix = normalizePrefix(url.searchParams.get('prefix') ?? '');
  const query = getBucketContentsQueryOptions(bucketName, prefix);

  // Our API returns results in ~1-2 seconds for large buckets, so we don't want to 
  // await this and block the UI. Instead, we let the component handle the loading state.
  queryClient.prefetchQuery(query);
};

const BucketContentsRoute = () => {
  const params = useParams();
  const bucketName = params.bucketName as string;

  return (
    <>
      <title>{`Bucket ${bucketName} contents`}</title>
      <BucketContentsTable />
    </>
  );
};

export default BucketContentsRoute;