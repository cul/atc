import { queryOptions, useQuery } from '@tanstack/react-query';
import { QueryConfig } from '@/lib/react-query';
import { api } from '@/lib/api-client';
import { CsvExportDetailsResponse } from '../utils/csv-exports-utils';

const getCsvExportDetails = (exportId: string) => {
  const endpoint = `/csv_exports/${exportId}`;

  return api.get<CsvExportDetailsResponse>(endpoint);
};

type UseCsvExportSummariesOptions = {
  exportId: string;
  queryConfig?: QueryConfig<typeof getCsvExportDetailsQueryOptions>;
};

export const getCsvExportDetailsQueryOptions = (exportId: string) => {
  return queryOptions({
    queryKey: ['csv-export-details', `export-id-${exportId}`],
    queryFn: () => getCsvExportDetails(exportId),
  });
};

export const useCsvExportDetailsQuery = ({
  exportId,
  queryConfig,
}: UseCsvExportSummariesOptions) => {
  return useQuery({
    ...getCsvExportDetailsQueryOptions(exportId),
    ...queryConfig,
  });
};
