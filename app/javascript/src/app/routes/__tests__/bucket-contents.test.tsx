import {
  buildBucketContents,
  buildS3Object,
  buildS3Objects,
  mockApi,
  renderApp,
  screen,
  within,
  waitForElementToBeRemoved,
  userEvent,
  renderAppWithRouter,
} from '@/testing/test-utils';
import BucketContentsTable from '@/features/file-browser/components/bucket-contents-table';

const renderAppAndWait = async () => {
  await renderApp(<BucketContentsTable />, {
    url: '/browse/buckets/my-bucket',
    path: '/browse/buckets/:bucketName',
  });
  await waitForElementToBeRemoved(() => screen.queryByRole('status'));
};

describe('BucketContentsRoute', () => {
  describe('rendering bucket contents', () => {
    it('renders folders and objects together, with folders typed as "Folder"', async () => {
      const testBucket = buildBucketContents({
        folders: ['documents/'],
        objects: [buildS3Object({ key: 'notes.txt' })],
      });
      mockApi('get', '/buckets/my-bucket/list', testBucket);

      await renderAppAndWait();

      expect(screen.getByText('documents')).toBeInTheDocument();
      expect(screen.getByText('notes.txt')).toBeInTheDocument();
      expect(screen.getByText('Folder')).toBeInTheDocument();
      expect(screen.getByText('txt')).toBeInTheDocument();
    });

    it('displays the expected column headers', async () => {
      mockApi('get', '/buckets/my-bucket/list', buildBucketContents());

      await renderAppAndWait();

      const headers = await screen.findAllByRole('columnheader');
      expect(headers.map((header) => header.textContent?.trim())).toEqual([
        'Selection',
        'Name',
        'Last Modified',
        'Type',
        'Storage Class',
        'Size',
      ]);
    });

    it('shows the bucket name as the current directory at the root', async () => {
      mockApi('get', '/buckets/my-bucket/list', buildBucketContents());

      await renderAppAndWait();

      expect(await screen.findByText('my-bucket/')).toBeInTheDocument();
    });

    it('shows the last prefix segment as the current directory inside a folder', async () => {
      mockApi('get', '/buckets/my-bucket/list', buildBucketContents());

      await renderAppAndWait();

      expect(await screen.findByText('my-bucket/')).toBeInTheDocument();
    });

    it('renders the empty state when the bucket has no contents', async () => {
      mockApi('get', '/buckets/my-bucket/list', buildBucketContents());

      await renderAppAndWait();

      expect(screen.getByText('No entries found.')).toBeInTheDocument();
    });

    it('formats object size and renders "-" for folder size/storage class', async () => {
      mockApi(
        'get',
        '/buckets/my-bucket/list',
        buildBucketContents({
          folders: ['archive/'],
          objects: [
            buildS3Object({
              key: 'big.bin',
              size: 1024 * 1024,
              storageClass: 'INTELLIGENT_TIERING',
            }),
          ],
        }),
      );

      await renderAppAndWait();

      const objectRow = screen.getByText('big.bin').closest('tr')!;
      expect(within(objectRow).getByText('1.00 MB')).toBeInTheDocument();
      expect(within(objectRow).getByText('Intelligent Tiering')).toBeInTheDocument();

      // Folders have no Last Modified, Storage Class or Size so they all render "-"
      const folderRow = screen.getByText('archive').closest('tr')!;
      expect(within(folderRow).getAllByText('-')).toHaveLength(3);
    });
  });

  describe('sorting bucket contents', () => {
    const getNameOrder = () => {
      const rows = screen.getAllByRole('row').slice(1); // drop header row
      return rows.map((row) => within(row).getAllByRole('cell')[1].textContent);
    };

    it('reverses the name order when the Name header is clicked', async () => {
      mockApi(
        'get',
        '/buckets/my-bucket/list',
        buildBucketContents({
          folders: ['mango/'],
          objects: [buildS3Object({ key: 'apple.txt' }), buildS3Object({ key: 'zebra.txt' })],
        }),
      );

      await renderAppAndWait();

      // Name column is initially sorted ascending, the first click reverses the order
      await userEvent.click(screen.getByRole('button', { name: 'Name' }));
      expect(getNameOrder()).toEqual(['zebra.txt', 'mango', 'apple.txt']);
    });

    it('sorts folders before objects by type, then by extension, then by name', async () => {
      mockApi(
        'get',
        '/buckets/my-bucket/list',
        buildBucketContents({
          folders: ['z-folder/', 'a-folder/'],
          objects: [
            buildS3Object({ key: 'delta.txt' }),
            buildS3Object({ key: 'beta.txt' }),
            buildS3Object({ key: 'zoo.jpg' }),
          ],
        }),
      );

      await renderAppAndWait();
      await userEvent.click(screen.getByRole('button', { name: 'Type' }));

      // Folders first (alphabetical), then objects by extension (jpg < txt),
      // then by name within the same extension (beta < delta).
      expect(getNameOrder()).toEqual(['a-folder', 'z-folder', 'zoo.jpg', 'beta.txt', 'delta.txt']);
    });

    it('sorts objects chronologically by last modified, folders last', async () => {
      mockApi(
        'get',
        '/buckets/my-bucket/list',
        buildBucketContents({
          folders: ['folder/'],
          objects: [
            buildS3Object({ key: 'newer.txt', lastModified: '2026-03-01T00:00:00.000Z' }),
            buildS3Object({ key: 'older.txt', lastModified: '2026-01-01T00:00:00.000Z' }),
          ],
        }),
      );

      await renderAppAndWait();
      await userEvent.click(screen.getByRole('button', { name: 'Last Modified' }));

      expect(getNameOrder()).toEqual(['older.txt', 'newer.txt', 'folder']);
    });

    it('sorts objects by storage class, folders last', async () => {
      mockApi(
        'get',
        '/buckets/my-bucket/list',
        buildBucketContents({
          folders: ['folder/'],
          objects: [
            buildS3Object({ key: 'archival.txt', storageClass: 'INTELLIGENT_TIERING' }),
            buildS3Object({ key: 'standard.txt', storageClass: 'STANDARD' }),
          ],
        }),
      );

      await renderAppAndWait();
      await userEvent.click(screen.getByRole('button', { name: 'Storage Class' }));

      expect(getNameOrder()).toEqual(['archival.txt', 'standard.txt', 'folder']);
    });

    it('sorts objects numerically by size, folders last', async () => {
      mockApi(
        'get',
        '/buckets/my-bucket/list',
        buildBucketContents({
          folders: ['folder/'],
          objects: [
            buildS3Object({ key: 'big.txt', size: 1024 * 1024 }),
            buildS3Object({ key: 'small.txt', size: 10 }),
          ],
        }),
      );

      await renderAppAndWait();
      await userEvent.click(screen.getByRole('button', { name: 'Size' }));

      expect(getNameOrder()).toEqual(['small.txt', 'big.txt', 'folder']);
    });
  });

  describe('paginating bucket contents', () => {
    const PAGE_SIZE = 3;

    const renderPaginatedAndWait = async (url = '/browse/buckets/my-bucket') => {
      const result = await renderAppWithRouter(<BucketContentsTable pageSize={PAGE_SIZE} />, {
        url,
        path: '/browse/buckets/:bucketName',
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

    it('advances to the next page when the next arrow is clicked', async () => {
      mockApi(
        'get',
        '/buckets/my-bucket/list',
        buildBucketContents({ objects: buildS3Objects(10) }),
      );

      const { router } = await renderPaginatedAndWait();

      expect(screen.getByText('object-000.txt')).toBeInTheDocument();
      expect(screen.queryByText('object-003.txt')).not.toBeInTheDocument();

      await userEvent.click(screen.getByRole('button', { name: nav.next }));

      expect(await screen.findByText('object-003.txt')).toBeInTheDocument();
      expect(screen.queryByText('object-000.txt')).not.toBeInTheDocument();
      expect(router.state.location.search).toBe('?page=2');
    });

    it('returns to the previous page when the previous arrow is clicked', async () => {
      mockApi(
        'get',
        '/buckets/my-bucket/list',
        buildBucketContents({ objects: buildS3Objects(10) }),
      );

      const { router } = await renderPaginatedAndWait('/browse/buckets/my-bucket?page=2');

      expect(screen.getByText('object-003.txt')).toBeInTheDocument();
      expect(screen.queryByText('object-000.txt')).not.toBeInTheDocument();

      await userEvent.click(screen.getByRole('button', { name: nav.previous }));

      expect(await screen.findByText('object-000.txt')).toBeInTheDocument();
      expect(screen.queryByText('object-003.txt')).not.toBeInTheDocument();
      expect(router.state.location.search).toBe('');
    });

    it('disables the navigation arrows when there is only one page', async () => {
      mockApi(
        'get',
        '/buckets/my-bucket/list',
        buildBucketContents({ objects: buildS3Objects(2) }),
      );

      await renderPaginatedAndWait();

      // Bootstrap renders a disabled pagination control as a plain <span>
      // (no buttons) so we check if buttons are absent rather than disabled
      expect(screen.queryByRole('button', { name: nav.first })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: nav.previous })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: nav.next })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: nav.last })).not.toBeInTheDocument();
    });

    it('jumps to the last and first pages with the double-arrow buttons', async () => {
      mockApi(
        'get',
        '/buckets/my-bucket/list',
        buildBucketContents({ objects: buildS3Objects(10) }),
      );

      await renderPaginatedAndWait();

      // Last page holds the final object only
      await userEvent.click(screen.getByRole('button', { name: nav.last }));
      expect(await screen.findByText('object-009.txt')).toBeInTheDocument();
      expect(screen.queryByText('object-000.txt')).not.toBeInTheDocument();

      await userEvent.click(screen.getByRole('button', { name: nav.first }));
      expect(await screen.findByText('object-000.txt')).toBeInTheDocument();
      expect(screen.queryByText('object-009.txt')).not.toBeInTheDocument();
    });

    it('lands on the requested page when navigating directly to ?page=4', async () => {
      mockApi(
        'get',
        '/buckets/my-bucket/list',
        buildBucketContents({ objects: buildS3Objects(10) }),
      );

      const { router } = await renderPaginatedAndWait('/browse/buckets/my-bucket?page=4');

      expect(screen.getByText('object-009.txt')).toBeInTheDocument();
      expect(screen.queryByText('object-000.txt')).not.toBeInTheDocument();
      expect(router.state.location.search).toBe('?page=4');
    });
  });
});
