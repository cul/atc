import { LoaderFunctionArgs, useSearchParams } from 'react-router';
import { QueryClient } from '@tanstack/react-query';
import { getObjectDetailsQueryOptions } from '@/features/file-browser/api/get-object-details';
import ObjectDetailDisplay from '@/features/file-browser/components/object-detail-display';

export const clientLoader =
  (queryClient: QueryClient) =>
  async ({ params, request }: LoaderFunctionArgs) => {
    const bucketName = params.bucketName as string;
    const url = new URL(request.url);
    const key = url.searchParams.get('prefix') ?? '';
    const query = getObjectDetailsQueryOptions(bucketName, key);

    await queryClient.prefetchQuery(query);
  };

const ObjectDetailsRoute = () => {
  const [searchParams] = useSearchParams();
  const key = searchParams.get('prefix') ?? '';

  return (
    <>
      <title>{`Object Details - ${key}`}</title>
      <ObjectDetailDisplay />
    </>
  );
};

export default ObjectDetailsRoute;
