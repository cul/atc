import { QueryClient } from '@tanstack/react-query';
import { getObjectDetailsQueryOptions } from '@/features/file-browser/api/get-object-details';
import { LoaderFunctionArgs } from 'react-router';

export const clientLoader = (queryClient: QueryClient) => async ({ params, request }: LoaderFunctionArgs) => {
  const bucketName = params.bucketName as string;
  const url = new URL(request.url);
  const key = url.searchParams.get('prefix') ?? '';
  const query = getObjectDetailsQueryOptions(bucketName, key);

  await queryClient.prefetchQuery(query);
};

const ObjectDetailsRoute = () => {
  return <div>Object Details</div>;
};

export default ObjectDetailsRoute;