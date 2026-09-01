import { Outlet } from 'react-router';

const CsvExportsLayout = () => {
  return (
    <div className="container mx-auto p-4">
      <main>
        <Outlet />
      </main>
    </div>
  );
};

export default CsvExportsLayout;
