import { getCsvExportSummariesQueryOptions } from '@/features/csv-exports/api/get-csv-export-summaries';
import CsvExportsTable from '@/features/csv-exports/components/csv-exports-table';
import { QueryClient } from '@tanstack/react-query';
import { LoaderFunctionArgs } from 'react-router';

export const clientLoader =
  (queryClient: QueryClient) =>
  async ({ params, request }: LoaderFunctionArgs) => {
    // load exports to cache
    console.log('client loader for exports');
    // todo : make sure pagination works!

    // GET /api/csv_exports?page=<pageNo>perPage=<perPage>
    const query = getCsvExportSummariesQueryOptions(params.pageIndex, params.perPage);
    queryClient.prefetchQuery(query);
  };

const CsvExportsRoute = () => {
  return (
    <>
      <title>CSV Exports</title>
      <CsvExportsTable />
    </>
  );
};

export default CsvExportsRoute;
