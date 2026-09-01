import { buildBucket, mockApi, renderApp, screen, within } from '@/testing/test-utils';
import BucketList from '@/features/file-browser/components/bucket-list';

describe('BucketsRoute', () => {
  it('renders a list of buckets', async () => {
    const bucket1 = buildBucket({ name: 'bucket-1' });
    const bucket2 = buildBucket({ name: 'bucket-2' });

    mockApi('get', '/buckets', { buckets: [bucket1, bucket2] });

    await renderApp(<BucketList />, { url: '/buckets' });

    expect(await screen.findByRole('heading', { name: 'S3 Buckets' })).toBeInTheDocument();
    expect(await screen.findByText('bucket-1')).toBeInTheDocument();
    expect(await screen.findByText('bucket-2')).toBeInTheDocument();
  });

  it('should display correct column headers', async () => {
    const bucket1 = buildBucket({ name: 'bucket-1' });
    const bucket2 = buildBucket({ name: 'bucket-2' });

    mockApi('get', '/buckets', { buckets: [bucket1, bucket2] });

    await renderApp(<BucketList />, { url: '/buckets' });

    const columnHeaders = await screen.findAllByRole('columnheader');
    const columnHeaderNames = columnHeaders.map((header) => header.textContent);

    expect(columnHeaderNames).toEqual(['Name', 'Description']);
  });

  it('should display data sorted in ascending order by name', async () => {
    const bucket1 = buildBucket({ name: 'z-bucket' });
    const bucket2 = buildBucket({ name: 'a-bucket' });
    const bucket3 = buildBucket({ name: 'm-bucket' });

    mockApi('get', '/buckets', { buckets: [bucket1, bucket2, bucket3] });

    await renderApp(<BucketList />, { url: '/buckets' });

    await screen.findByRole('table');

    const rows = screen.getAllByRole('row');
    const names = rows.slice(1).map((row) => within(row).getAllByRole('cell')[0].textContent);

    expect(names).toEqual(['a-bucket', 'm-bucket', 'z-bucket']);
  });
});
