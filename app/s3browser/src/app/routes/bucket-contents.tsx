import { QueryClient } from '@tanstack/react-query';
import { LoaderFunctionArgs } from 'react-router';

// Prefix has to end with '/' for S3 ListObjectsV2 to treat it as a folder
const normalizePrefix = (raw: string): string => {
  if (!raw) return '';
  return raw.endsWith('/') ? raw : `${raw}/`;
};

export const clientLoader = (queryClient: QueryClient) => async ({ params }: LoaderFunctionArgs) => {
  const bucketName = params.bucketName as string;
  const prefix = normalizePrefix(params['*'] ?? '');
  console.log('Loading bucket contents for', bucketName, 'with prefix', prefix);
};

const BucketContentsRoute = () => {
  return <div>Bucket Contents</div>;
};

export default BucketContentsRoute;