import {
  mockApi,
  renderApp,
  renderAppWithRouter,
  screen,
  userEvent,
  waitForElementToBeRemoved,
  within,
} from '@/testing/test-utils';
import CsvExportsRoute from '../csv-exports';
import {
  buildCsvExportSummary,
  buildCsvExportSummaryArray,
  buildCsvExportSummaryResponse,
} from '@/testing/data-generators';
import { mockServerPaginatedCsvExports } from '@/testing/mock-api';

const mockApi3Pages = () => {
  const testPaginationData1 = {
    currentPage: 1,
    perPage: 20,
    totalPages: 3,
    totalCount: 60,
  };
  const testPaginationData2 = {
    currentPage: 2,
    perPage: 20,
    totalPages: 3,
    totalCount: 60,
  };
  const testPaginationData3 = {
    currentPage: 3,
    perPage: 20,
    totalPages: 3,
    totalCount: 60,
  };
  const response1 = buildCsvExportSummaryResponse({
    csvExports: buildCsvExportSummaryArray(20),
    pagination: testPaginationData1,
  });
  const response2 = buildCsvExportSummaryResponse({
    csvExports: buildCsvExportSummaryArray(20),
    pagination: testPaginationData2,
  });
  const response3 = buildCsvExportSummaryResponse({
    csvExports: buildCsvExportSummaryArray(20),
    pagination: testPaginationData3,
  });

  mockServerPaginatedCsvExports({
    '1': response1,
    '2': response2,
    '3': response3,
  });
};

const renderRouteAndMock = async (pageNumber?: number) => {
  const response = buildCsvExportSummaryResponse();
  mockApi('get', '/csv_exports', response);
  renderApp(<CsvExportsRoute />, {
    url: `/csv_exports${pageNumber ? `?page=${encodeURIComponent(pageNumber)}` : ''}`,
  });
};

const renderRoute = (pageNumber?: number) =>
  renderApp(<CsvExportsRoute />, {
    url: `/csv_exports${pageNumber ? `?page=${encodeURIComponent(pageNumber)}` : ''}`,
  });

describe('CsvExportsRoute', () => {
  it('renders the table of CSV Export summaries', async () => {
    await renderRouteAndMock();

    expect(await screen.findByRole('heading')).toHaveTextContent('CSV Exports');
    const table = screen.getByRole('table');
    const row1 = (await within(table).findByRole('link', { name: '1' })).closest('tr');
    const row2 = (await within(table).findByRole('link', { name: '2' })).closest('tr');
    expect(within(row1).getAllByRole('cell')[0]).toHaveTextContent('1');
    expect(within(row1).getAllByRole('cell')[1]).toHaveTextContent('success');
    expect(within(row2).getAllByRole('cell')[0]).toHaveTextContent('2');
    expect(within(row2).getAllByRole('cell')[1]).toHaveTextContent('success');
  });

  it('should display correct column headers', async () => {
    await renderRouteAndMock();

    const columnHeaders = await screen.findAllByRole('columnheader');
    const columnHeaderNames = columnHeaders.map((header) => header.textContent);

    expect(columnHeaderNames).toEqual([
      'ID',
      'Export Status',
      'Selected Items',
      'Total Selected Items',
      'Last Updated',
    ]);
  });

  it('should display data sorted in descending order by id', async () => {
    await renderRouteAndMock();

    const table = await screen.findByRole('table');

    // Wait for table content to render
    (await within(table).findByRole('link', { name: '1' })).closest('tr');

    const rows = screen.getAllByRole('row');
    const names = rows.slice(1).map((row) => within(row).getAllByRole('cell')[0].textContent);

    expect(names).toEqual(['2', '1', '0']);
  });

  it('includes a download link for rows that have success or completed_with_error status', async () => {
    const response = buildCsvExportSummaryResponse({
      csvExports: [
        buildCsvExportSummary({ id: 20 }),
        buildCsvExportSummary({ id: 21, status: 'completed_with_errors' }),
      ],
    });
    mockApi('get', '/csv_exports', response);
    await renderRoute();

    const table = await screen.findByRole('table');
    const row1 = (await within(table).findByRole('link', { name: '20' })).closest('tr');
    const row2 = (await within(table).findByRole('link', { name: '21' })).closest('tr');
    expect(within(row1).getAllByRole('cell')[1]).toHaveTextContent('success');
    expect(within(row1).getByRole('button', { name: 'Download' })).toBeInTheDocument();
    expect(within(row2).getAllByRole('cell')[1]).toHaveTextContent('completed_with_errors');
    expect(within(row2).getByRole('button', { name: 'Download' })).toBeInTheDocument();
  });

  describe('paginating csv exports', () => {
    const renderPaginatedAndWait = async (url = '/csv_exports?page=1') => {
      const result = await renderAppWithRouter(<CsvExportsRoute />, {
        url,
        path: '/csv_exports',
      });
      await waitForElementToBeRemoved(() => screen.queryByRole('status'));
      return result;
    };

    // Bootstrap's pagination buttons
    const nav = {
      first: /^first$/i,
      previous: /^previous$/i,
      next: /^next$/i,
      last: /^last$/i,
    };

    it('has correct pagination information displayed when navigating directly to page 2', async () => {
      mockApi3Pages();
      const { router } = await renderPaginatedAndWait(`/csv_exports?page=${encodeURIComponent(2)}`);

      expect(await screen.findByText('2 of 3')).toBeInTheDocument();
      expect(screen.getByText('Showing 21-40 of 60')).toBeInTheDocument();
      expect(router.state.location.search).toBe('?page=2');
    });

    it('correctly shows server side-paginated data when advancing thru pages', async () => {
      mockApi3Pages();
      const { router } = await renderPaginatedAndWait(`/csv_exports`);

      // Start on page 1
      expect(await screen.findByText('1 of 3')).toBeInTheDocument();
      expect(screen.getByText('Showing 1-20 of 60')).toBeInTheDocument();

      // Click to page 2
      await userEvent.click(screen.getByRole('button', { name: nav.next }));
      expect(await screen.findByText('2 of 3')).toBeInTheDocument();
      expect(screen.getByText('Showing 21-40 of 60')).toBeInTheDocument();
      expect(router.state.location.search).toBe('?page=2');

      // Click to page 3
      await userEvent.click(screen.getByRole('button', { name: nav.next }));
      expect(await screen.findByText('3 of 3')).toBeInTheDocument();
      expect(screen.getByText('Showing 41-60 of 60')).toBeInTheDocument();
      expect(router.state.location.search).toBe('?page=3');
    });

    it('correctly shows server side-paginated data when going back thru pages', async () => {
      mockApi3Pages();
      const { router } = await renderPaginatedAndWait(`/csv_exports?page=${encodeURIComponent(3)}`);

      // Start on page 3
      expect(await screen.findByText('3 of 3')).toBeInTheDocument();
      expect(screen.getByText('Showing 41-60 of 60')).toBeInTheDocument();
      expect(router.state.location.search).toBe('?page=3');

      // Click to page 2
      await userEvent.click(screen.getByRole('button', { name: nav.previous }));
      expect(await screen.findByText('2 of 3')).toBeInTheDocument();
      expect(screen.getByText('Showing 21-40 of 60')).toBeInTheDocument();
      expect(router.state.location.search).toBe('?page=2');

      // Click to page 1
      await userEvent.click(screen.getByRole('button', { name: nav.previous }));
      expect(await screen.findByText('1 of 3')).toBeInTheDocument();
      expect(screen.getByText('Showing 1-20 of 60')).toBeInTheDocument();
    });

    it('disables the navigation arrows when there is only one page', async () => {
      mockApi('get', '/csv_exports', buildCsvExportSummaryResponse());
      await renderPaginatedAndWait(`/csv_exports`);
      expect(await screen.findByText('1 of 1')).toBeInTheDocument();
      expect(screen.queryByRole('button', { name: nav.first })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: nav.previous })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: nav.next })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: nav.last })).not.toBeInTheDocument();
    });

    it('jumps to last and first pages with the double-arrow buttons', async () => {
      mockApi3Pages();
      const { router } = await renderPaginatedAndWait(`/csv_exports`);

      // Start on page 1
      expect(await screen.findByText('1 of 3')).toBeInTheDocument();
      expect(screen.getByText('Showing 1-20 of 60')).toBeInTheDocument();

      // Jump to page 3
      await userEvent.click(screen.getByRole('button', { name: nav.last }));
      expect(await screen.findByText('3 of 3')).toBeInTheDocument();
      expect(screen.getByText('Showing 41-60 of 60')).toBeInTheDocument();
      expect(router.state.location.search).toBe('?page=3');

      // Jump to page 1
      await userEvent.click(screen.getByRole('button', { name: nav.first }));
      expect(await screen.findByText('1 of 3')).toBeInTheDocument();
      expect(screen.getByText('Showing 1-20 of 60')).toBeInTheDocument();
    });
  });
});
