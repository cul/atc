import { queryOptions, useSuspenseQuery } from '@tanstack/react-query';
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

export const useCsvExportDetailsSuspense = ({
  exportId,
  queryConfig,
}: UseCsvExportSummariesOptions) => {
  return useSuspenseQuery({
    ...getCsvExportDetailsQueryOptions(exportId),
    ...queryConfig,
  });
};
