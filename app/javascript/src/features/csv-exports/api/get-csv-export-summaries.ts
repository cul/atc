import { queryOptions, useQuery } from '@tanstack/react-query';
import { QueryConfig } from '@/lib/react-query';
import { api } from '@/lib/api-client';
import {
  CsvExportSummariesResponse,
  DEFAULT_CSV_EXPORT_PAGE_SIZE,
} from '../utils/csv-exports-utils';

const getCsvExportSummaries = (pageIndex = 1, perPage = DEFAULT_CSV_EXPORT_PAGE_SIZE) => {
  const params = new URLSearchParams();

  params.set('page', `${pageIndex}`);
  params.set('perPage', `${perPage}`);

  const endpoint = `/csv_exports?${params}`;

  return api.get<CsvExportSummariesResponse>(endpoint);
};

type UseCsvExportSummariesOptions = {
  pageIndex: number;
  perPage: number;
  queryConfig?: QueryConfig<typeof getCsvExportSummariesQueryOptions>;
};

export const getCsvExportSummariesQueryOptions = (pageIndex: number, perPage: number) => {
  return queryOptions({
    queryKey: ['csv-export-summaries', `index-${pageIndex}`, `perPage-${perPage}`],
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
