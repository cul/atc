import { getCsvExportDetailsQueryOptions } from '@/features/csv-exports/api/get-csv-export-details';
import CsvExportDetailsDisplay from '@/features/csv-exports/components/csv-export-details-display';
import { QueryClient } from '@tanstack/react-query';
import { LoaderFunctionArgs } from 'react-router';

export const clientLoader =
  (queryClient: QueryClient) =>
  async ({ params }: LoaderFunctionArgs) => {
    queryClient.prefetchQuery(getCsvExportDetailsQueryOptions(params.id));
  };

const CsvExportDetailsRoute = () => {
  return (
    <>
      <title>CSV Export Details</title>
      <CsvExportDetailsDisplay />
    </>
  );
};

export default CsvExportDetailsRoute;
