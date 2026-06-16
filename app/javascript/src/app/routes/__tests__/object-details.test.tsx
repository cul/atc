import { describe, it, expect } from 'vitest';
import {
  buildObjectDetails,
  mockApi,
  renderApp,
  screen,
  within,
  waitFor,
} from '@/testing/test-utils';
import ObjectDetailsRoute from '@/app/routes/object-details';

const renderRoute = (objectKey: string, bucketName = 'test-bucket') =>
  renderApp(<ObjectDetailsRoute />, {
    url: `/browse/buckets/${bucketName}/object-details?prefix=${encodeURIComponent(objectKey)}`,
    path: '/browse/buckets/:bucketName/object-details',
  });

// MSW matches on pathname and ignores the query string,
// so we register the endpoint without the "?key=" part"
const mockObjectDetails = (
  details: ReturnType<typeof buildObjectDetails>,
  bucketName = 'test-bucket',
) => mockApi('get', `/buckets/${bucketName}/object`, details);

// Each field renders as <div> wrapping label <dt> and value <dd>
const fieldByLabel = (label: string) => {
  const wrapper = screen.getByText(label).closest('div');
  if (!wrapper) throw new Error(`Could not find field wrapper for label: ${label}`);
  return within(wrapper);
};

describe('ObjectDetailsRoute', () => {
  it('fetches and renders the object information', async () => {
    mockObjectDetails(
      buildObjectDetails({
        key: 'documents/report.pdf',
        size: 2060,
        storageClass: 'STANDARD',
        lastModified: '2026-01-15T10:30:00.000Z',
      }),
    );

    await renderRoute('documents/report.pdf');

    expect(await screen.findByRole('heading', { name: 'report.pdf' })).toBeInTheDocument();

    expect(fieldByLabel('Key').getByText('documents/report.pdf')).toBeInTheDocument();
    expect(fieldByLabel('Type').getByText('pdf')).toBeInTheDocument();
    expect(fieldByLabel('Size').getByText('2.01 kB')).toBeInTheDocument();
    expect(fieldByLabel('Last modified').getByText(/January 15, 2026/)).toBeInTheDocument();
  });

  it('sets the document title from the object key', async () => {
    mockObjectDetails(buildObjectDetails({ key: 'documents/report.pdf' }));

    await renderRoute('documents/report.pdf');

    await screen.findByRole('heading', { name: 'report.pdf' });
    await waitFor(() => expect(document.title).toBe('Object Details - documents/report.pdf'));
  });

  it('shows "unknown" type when the key has no file extension', async () => {
    mockObjectDetails(buildObjectDetails({ key: 'README' }));

    await renderRoute('README');

    expect(await screen.findByRole('heading', { name: 'README' })).toBeInTheDocument();
    expect(fieldByLabel('Type').getByText('unknown')).toBeInTheDocument();
  });

  it('omits the archive-specific fields for STANDARD storage class', async () => {
    mockObjectDetails(buildObjectDetails({ storageClass: 'STANDARD' }));

    await renderRoute('documents/report.pdf');

    expect(await screen.findByText('Standard')).toBeInTheDocument();
    expect(screen.queryByText('Access tier')).not.toBeInTheDocument();
    expect(screen.queryByText('Retrieval time')).not.toBeInTheDocument();
    expect(screen.queryByText('Restoration status')).not.toBeInTheDocument();
  });

  it('renders Archive Access tier with a 5 hour retrieval time', async () => {
    mockObjectDetails(
      buildObjectDetails({
        storageClass: 'INTELLIGENT_TIERING',
        archiveStatus: 'ARCHIVE_ACCESS',
        restoreStatus: null,
      }),
    );

    await renderRoute('documents/report.pdf');

    await screen.findByText('Intelligent Tiering');
    expect(fieldByLabel('Access tier').getByText('Archive Access')).toBeInTheDocument();
    expect(fieldByLabel('Retrieval time').getByText('5 hours')).toBeInTheDocument();
    expect(
      fieldByLabel('Restoration status').getByText('No restoration currently in progress'),
    ).toBeInTheDocument();
  });

  it('renders Deep Archive Access tier with a 12 hour retrieval time', async () => {
    mockObjectDetails(
      buildObjectDetails({
        storageClass: 'INTELLIGENT_TIERING',
        archiveStatus: 'DEEP_ARCHIVE_ACCESS',
      }),
    );

    await renderRoute('documents/report.pdf');

    await screen.findByText('Intelligent Tiering');
    expect(fieldByLabel('Access tier').getByText('Deep Archive Access')).toBeInTheDocument();
    expect(fieldByLabel('Retrieval time').getByText('12 hours')).toBeInTheDocument();
  });

  it('shows instant-access for a non-standard object without an archive status', async () => {
    mockObjectDetails(
      buildObjectDetails({
        storageClass: 'INTELLIGENT_TIERING',
        archiveStatus: null,
      }),
    );

    await renderRoute('documents/report.pdf');

    await screen.findByText('Intelligent Tiering');
    expect(
      fieldByLabel('Access tier').getByText(/Frequent Access, Infrequent Access/),
    ).toBeInTheDocument();
    expect(
      fieldByLabel('Retrieval time').getByText('Milliseconds (instant access)'),
    ).toBeInTheDocument();
  });

  it('displays in-progress restoration status when the object is being restored', async () => {
    mockObjectDetails(
      buildObjectDetails({
        storageClass: 'INTELLIGENT_TIERING',
        archiveStatus: 'ARCHIVE_ACCESS',
        restoreStatus: 'IN_PROGRESS',
      }),
    );

    await renderRoute('documents/report.pdf');

    await screen.findByText('Intelligent Tiering');
    expect(fieldByLabel('Restoration status').getByText('In Progress')).toBeInTheDocument();
  });
});
