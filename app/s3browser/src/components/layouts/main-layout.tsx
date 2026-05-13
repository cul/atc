import { Outlet, useParams, useSearchParams } from 'react-router';
import Breadcrumbs from '@/features/file-browser/components/breadcrumbs';

const MainLayout = () => {
  const { bucketName } = useParams();
  const [searchParams] = useSearchParams();
  const prefix = searchParams.get('prefix') ?? undefined;
  console.log('MainLayout params', { bucketName, prefix });

  return (
    <div>
      <Breadcrumbs bucketName={bucketName} prefix={prefix} />
      <Outlet />
    </div>
  );
};

export default MainLayout;