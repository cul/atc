import { Outlet, useParams, useSearchParams } from 'react-router';
import Breadcrumbs from '@/features/file-browser/components/breadcrumbs';

const MainLayout = () => {
  const { bucketName } = useParams();
  const [searchParams] = useSearchParams();
  const prefix = searchParams.get('prefix') ?? undefined;

  return (
    <div className="container mx-auto p-4">
      <Breadcrumbs bucketName={bucketName} prefix={prefix} />
      <main>
        <Outlet />
      </main>
    </div>
  );
};

export default MainLayout;