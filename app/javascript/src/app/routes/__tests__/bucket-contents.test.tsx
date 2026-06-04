import { describe, it, expect } from 'vitest';
import {
  buildBucketContents,
  buildS3Object,
  mockApi,
  renderApp,
  screen,
  within,
  waitForElementToBeRemoved,
} from '@/testing/test-utils';
import BucketContentsTable from '@/features/file-browser/components/bucket-contents-table';

describe('BucketContentsRoute', () => {
  it('renders folders and objects together, with folders typed as "Folder"', async () => {
    const testBucket = buildBucketContents({
      folders: ['documents/'],
      objects: [buildS3Object({ key: 'notes.txt' })],
    });
    mockApi('get', '/buckets/my-bucket/list', testBucket);

    await renderApp(<BucketContentsTable />, {
      url: '/browse/buckets/my-bucket',
      path: '/browse/buckets/:bucketName',
    });
    await waitForElementToBeRemoved(() => screen.queryByRole('status'));

    expect(screen.getByText('documents')).toBeInTheDocument();
    expect(screen.getByText('notes.txt')).toBeInTheDocument();
    expect(screen.getByText('Folder')).toBeInTheDocument();
    expect(screen.getByText('txt')).toBeInTheDocument();
  });

  it('displays the expected column headers', async () => {
    mockApi('get', '/buckets/my-bucket/list', buildBucketContents());

    await renderApp(<BucketContentsTable />, {
      url: '/browse/buckets/my-bucket',
      path: '/browse/buckets/:bucketName',
    });

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

    await renderApp(<BucketContentsTable />, {
      url: '/browse/buckets/my-bucket',
      path: '/browse/buckets/:bucketName',
    });

    expect(await screen.findByText('my-bucket/')).toBeInTheDocument();
  });

  it('shows the last prefix segment as the current directory inside a folder', async () => {
    mockApi('get', '/buckets/my-bucket/list', buildBucketContents());

    await renderApp(<BucketContentsTable />, {
      url: '/browse/buckets/my-bucket?prefix=documents/vacation/',
      path: '/browse/buckets/:bucketName',
    });

    expect(await screen.findByText('vacation/')).toBeInTheDocument();
  });

  it('renders the empty state when the bucket has no contents', async () => {
    mockApi('get', '/buckets/my-bucket/list', buildBucketContents());

    await renderApp(<BucketContentsTable />, {
      url: '/browse/buckets/my-bucket',
      path: '/browse/buckets/:bucketName',
    });
    await waitForElementToBeRemoved(() => screen.queryByRole('status'));

    expect(screen.getByText('No entries found.')).toBeInTheDocument();
  });

  it('formats object size and renders "-" for folder size/storage class', async () => {
    mockApi(
      'get',
      '/buckets/my-bucket/list',
      buildBucketContents({
        folders: ['archive/'],
        objects: [
          buildS3Object({ key: 'big.bin', size: 1024 * 1024, storageClass: 'INTELLIGENT_TIERING' }),
        ],
      }),
    );

    await renderApp(<BucketContentsTable />, {
      url: '/browse/buckets/my-bucket',
      path: '/browse/buckets/:bucketName',
    });
    await waitForElementToBeRemoved(() => screen.queryByRole('status'));

    const objectRow = screen.getByText('big.bin').closest('tr')!;
    expect(within(objectRow).getByText('1.00 MB')).toBeInTheDocument();
    expect(within(objectRow).getByText('Intelligent Tiering')).toBeInTheDocument();

    // Folders have no Last Modified, Storage Class or Size so they all render "-"
    const folderRow = screen.getByText('archive').closest('tr')!;
    expect(within(folderRow).getAllByText('-')).toHaveLength(3);
  });
});
