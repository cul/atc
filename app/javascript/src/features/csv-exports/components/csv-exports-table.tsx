import { useSearchParams } from 'react-router';
import { useCsvExportSummariesQuery } from '../api/get-csv-export-summaries';
import {
  DEFAULT_CSV_EXPORT_PAGE_SIZE,
  transformCsvExportSummaryToRow,
} from '../utils/csv-exports-utils';
import { useMemo } from 'react';
import TableBuilder from '@/components/ui/table-builder/table-builder';
import { columnDefs } from '../utils/csv-exports-column-defs';
import { usePagination } from '@/features/file-browser/hooks/use-pagination';

const CsvExportsTable = () => {
  const [searchParams] = useSearchParams();
  const pageIndex = Number(searchParams.get('page') ?? 1);
  const perPage = Number(searchParams.get('perPage') ?? DEFAULT_CSV_EXPORT_PAGE_SIZE);

  const { data, isLoading } = useCsvExportSummariesQuery({ pageIndex, perPage });

  const rowData = useMemo(() => {
    if (!data) return [];
    return data.csvExports.map((csvExport) => transformCsvExportSummaryToRow(csvExport));
  }, [data]);

  const { pagination, onPaginationChange } = usePagination(perPage);

  const columns = columnDefs;

  return (
    <div>
      <h4>
        <strong>CSV Exports</strong>
      </h4>
      <TableBuilder
        data={rowData}
        columns={columns}
        pagination={pagination}
        isServerSidePaginated={true}
        onPaginationChange={onPaginationChange}
        isLoading={isLoading}
        pageSize={perPage}
        rowCount={data?.pagination.totalCount}
      />
    </div>
  );
};

export default CsvExportsTable;
