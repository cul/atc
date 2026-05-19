import { LoaderFunctionArgs, useParams } from 'react-router';
import { QueryClient } from '@tanstack/react-query';
import { getObjectDetailsQueryOptions, useObjectDetailsSuspenseQuery } from '@/features/file-browser/api/get-object-details';
import ObjectDetailDisplay from '@/features/file-browser/components/object-detail-display';

export const clientLoader = (queryClient: QueryClient) => async ({ params, request }: LoaderFunctionArgs) => {
  const bucketName = params.bucketName as string;
  const url = new URL(request.url);
  const key = url.searchParams.get('prefix') ?? '';
  const query = getObjectDetailsQueryOptions(bucketName, key);

  await queryClient.prefetchQuery(query);
};

const ObjectDetailsRoute = () => {
  const params = useParams();
  const bucketName = params.bucketName as string;
  const url = new URL(window.location.href);
  const key = url.searchParams.get('prefix') ?? '';
  const query = useObjectDetailsSuspenseQuery({ bucket: bucketName, key });

  return <ObjectDetailDisplay objectDetails={query.data} />;
};

export default ObjectDetailsRoute;