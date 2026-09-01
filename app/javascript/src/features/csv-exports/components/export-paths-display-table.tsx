import TableBuilder from '@/components/ui/table-builder/table-builder';
import { columnDefs } from '../utils/csv-export-paths-column-defs';
import { convertToFullExportPathsList, ExportPath } from '../utils/csv-exports-utils';

type ExportPathsDisplayTableProps = {
  exportPaths: Array<ExportPath>;
};

const ExportPathsDisplayTable = ({ exportPaths }: ExportPathsDisplayTableProps) => {
  const combinedExportPaths = convertToFullExportPathsList(exportPaths);
  const columns = columnDefs;
  return (
    <div className="px-3">
      <small className="text-muted">
        A list of each item that was in the original selection when the CSV Export was ordered.
      </small>
      <TableBuilder data={combinedExportPaths} columns={columns} pageSize={50} />
    </div>
  );
};

export default ExportPathsDisplayTable;
