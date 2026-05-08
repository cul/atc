import { Outlet, useParams } from 'react-router';
import Breadcrumbs from '@/features/file-browser/components/breadcrumbs';

const MainLayout = () => {
  const { bucketName, '*': prefix } = useParams();
  
  return (
    <div>
      <Breadcrumbs bucketName={bucketName} prefix={prefix} />
      <Outlet />
    </div>
  );
};

export default MainLayout;