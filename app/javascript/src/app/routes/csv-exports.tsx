import { getCsvExportSummariesQueryOptions } from '@/features/csv-exports/api/get-csv-export-summaries';
import CsvExportsTable from '@/features/csv-exports/components/csv-exports-table';
import { QueryClient } from '@tanstack/react-query';
import { LoaderFunctionArgs } from 'react-router';

export const clientLoader =
  (queryClient: QueryClient) =>
  async ({ params }: LoaderFunctionArgs) => {
    const query = getCsvExportSummariesQueryOptions(
      Number(params.pageIndex),
      Number(params.perPage),
    );
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
