import { describe, it, expect } from 'vitest';
import {
  buildBucketContents,
  buildS3Object,
  mockApi,
  renderApp,
  screen,
  within,
  waitForElementToBeRemoved,
  userEvent,
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
      return rows.map((row) => within(row).getAllByRole('cell')[0].textContent);
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
});
