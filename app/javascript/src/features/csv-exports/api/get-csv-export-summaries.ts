import { api } from '@/lib/api-client';
import { CsvExportSummariesResponse } from '../utils/csv-exports-utils';
import { queryOptions, useQuery } from '@tanstack/react-query';
import { QueryConfig } from '@/lib/react-query';

const getCsvExportSummaries = (pageIndex: string = '1', perPage: string = '20') => {
  const params = new URLSearchParams();

  params.set('page', pageIndex);
  params.set('perPage', perPage);

  const endpoint = `/csv_exports?${params}`;
  console.log(`getting exports from : ${endpoint}`);

  return api.get<CsvExportSummariesResponse>(endpoint);
};

type UseCsvExportSummariesOptions = {
  pageIndex: string;
  perPage: string;
  queryConfig?: QueryConfig<typeof getCsvExportSummariesQueryOptions>;
};

export const getCsvExportSummariesQueryOptions = (pageIndex: string, perPage: string) => {
  return queryOptions({
    queryKey: ['csv-export-summaries', pageIndex, perPage],
    queryFn: () => getCsvExportSummaries(pageIndex, perPage),
  });
};

export const useCsvExportSummariesQuery = ({
  pageIndex,
  perPage,
  queryConfig,
}: UseCsvExportSummariesOptions) => {
  return useQuery({
    ...getCsvExportSummariesQueryOptions(pageIndex, perPage),
    ...queryConfig,
  });
};
