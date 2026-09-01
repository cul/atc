import { fieldByLabel, mockApi, renderApp, screen, within } from '@/testing/test-utils';
import { buildCsvExportDetailsResponse } from '@/testing/data-generators';
import CsvExportDetailsRoute from '../csv-export-details';

describe('CsvExportDetailsRoute', () => {
  it('renders the correct details page with expected data', async () => {
    mockApi('get', '/csv_exports/1', buildCsvExportDetailsResponse());
    await renderApp(<CsvExportDetailsRoute />, { url: '/csv_exports/1', path: '/csv_exports/:id' });
    await screen.findByRole('heading', { name: 'CSV Export Details' });

    expect(fieldByLabel('Export Status').getByText('SUCCESS')).toBeInTheDocument();
    expect(
      fieldByLabel('Download Report').getByRole('button', { name: 'Download' }),
    ).toBeInTheDocument();
    expect(fieldByLabel('Export ID').getByText('1')).toBeInTheDocument();
    expect(fieldByLabel('Number of Items Selected').getByText('6')).toBeInTheDocument();
    expect(
      fieldByLabel('Last Updated').getByText('January 15, 2026, 05:30:00'),
    ).toBeInTheDocument();
    expect(fieldByLabel('Export Paths').getByRole('table')).toBeInTheDocument();
  });

  it('has download button for success status', async () => {
    mockApi('get', '/csv_exports/1', buildCsvExportDetailsResponse());
    await renderApp(<CsvExportDetailsRoute />, { url: '/csv_exports/1', path: '/csv_exports/:id' });
    await screen.findByRole('heading', { name: 'CSV Export Details' });
    expect(
      fieldByLabel('Download Report').getByRole('button', { name: 'Download' }),
    ).toBeInTheDocument();
  });

  it('has download button for completed_with_errors status', async () => {
    mockApi(
      'get',
      '/csv_exports/1',
      buildCsvExportDetailsResponse({ status: 'completed_with_errors' }),
    );
    await renderApp(<CsvExportDetailsRoute />, { url: '/csv_exports/1', path: '/csv_exports/:id' });
    await screen.findByRole('heading', { name: 'CSV Export Details' });
    expect(
      fieldByLabel('Download Report').getByRole('button', { name: 'Download' }),
    ).toBeInTheDocument();
  });

  it('displays errors for failure status', async () => {
    mockApi(
      'get',
      '/csv_exports/1',
      buildCsvExportDetailsResponse({ status: 'failure', exportErrors: ['an error occurred'] }),
    );
    await renderApp(<CsvExportDetailsRoute />, { url: '/csv_exports/1', path: '/csv_exports/:id' });
    await screen.findByRole('heading', { name: 'CSV Export Details' });
    expect(fieldByLabel('Errors').getByText('an error occurred')).toBeInTheDocument();
  });

  it('displays errors for completed_with_errors status', async () => {
    mockApi(
      'get',
      '/csv_exports/1',
      buildCsvExportDetailsResponse({
        status: 'completed_with_errors',
        exportErrors: ['an error occurred', 'a different error occurred'],
      }),
    );
    await renderApp(<CsvExportDetailsRoute />, { url: '/csv_exports/1', path: '/csv_exports/:id' });
    await screen.findByRole('heading', { name: 'CSV Export Details' });
    expect(fieldByLabel('Errors').getByText('an error occurred')).toBeInTheDocument();
    expect(fieldByLabel('Errors').getByText('a different error occurred')).toBeInTheDocument();
  });

  it('lists correct headers for export paths table', async () => {
    mockApi('get', '/csv_exports/1', buildCsvExportDetailsResponse());
    await renderApp(<CsvExportDetailsRoute />, { url: '/csv_exports/1', path: '/csv_exports/:id' });
    await screen.findByRole('heading', { name: 'CSV Export Details' });

    const columnHeaders = await screen.findAllByRole('columnheader');
    const columnHeaderNames = columnHeaders.map((header) => header.textContent);

    expect(columnHeaderNames).toEqual(['#', 'Item Path', 'Bucket', 'Selection Type']);
  });

  it('lists correct headers for export paths table', async () => {
    mockApi('get', '/csv_exports/1', buildCsvExportDetailsResponse());
    await renderApp(<CsvExportDetailsRoute />, { url: '/csv_exports/1', path: '/csv_exports/:id' });
    await screen.findByRole('heading', { name: 'CSV Export Details' });

    const rows = screen.getAllByRole('row');
    const itemPaths = rows.slice(1).map((row) => within(row).getAllByRole('cell')[1].textContent);
    expect(itemPaths).toEqual([
      'a/b/c/',
      'a/b/file1.txt',
      'a/b/file2.txt',
      'a/b/c/',
      'a/b/file1.txt',
      'a/b/file2.txt',
    ]);
    const bucketCells = rows.slice(1).map((row) => within(row).getAllByRole('cell')[2].textContent);
    expect(bucketCells).toEqual([
      'bucket-a',
      'bucket-a',
      'bucket-a',
      'bucket-b',
      'bucket-b',
      'bucket-b',
    ]);
    const typeCells = rows.slice(1).map((row) => within(row).getAllByRole('cell')[3].textContent);
    expect(typeCells).toEqual(['folder', 'file', 'file', 'folder', 'file', 'file']);
  });
});
