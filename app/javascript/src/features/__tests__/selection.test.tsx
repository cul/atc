import MainLayout from '@/components/layouts/main-layout';
import {
  buildBucket,
  mockApi,
  screen,
  renderApp,
  within,
  userEvent,
  buildS3Object,
} from '@/testing/test-utils';
import { describe, it, expect, beforeEach } from 'vitest';
import BucketContentsTable from '../file-browser/components/bucket-contents-table';
import BucketList from '../file-browser/components/bucket-list';
import { mockBucketList } from '@/testing/mock-api';

const renderAppAndWait = async () => {
  // we will start at the bucket list level and navigate to individual bucket-content routes
  await renderApp(<MainLayout />, {
    url: '/browse/buckets',
    children: [
      {
        index: true,
        element: <BucketList />,
      },
      {
        path: ':bucketName',
        element: <BucketContentsTable />,
      },
    ],
  });
};

const clickToFolder1 = async () => {
  // navigate into bucket1/
  expect(await screen.findByRole('heading', { name: /S3 Buckets/ })).toBeInTheDocument();
  await userEvent.click(screen.getByRole('link', { name: 'bucket-1' }));
  await screen.findByText('objectA');
  // navigate into bucket1/folder1/
  await screen.findByText('bucket-1/');
  await screen.findByText('objectA'); // root-level item
  await userEvent.click(screen.getByRole('link', { name: 'folder1' }));
  await screen.findByText('objectB'); // now prefix = folder1/, mockBucketList returns the folder body
};

describe('Item Selection Feature', () => {
  beforeEach(async () => {
    // bucket-1:
    // - objectA
    // - folder1
    //   - objectB
    //   - objectC
    // bucket-2:
    // - objectD
    // - folder3
    const bucket1 = buildBucket({ name: 'bucket-1' });
    const bucket2 = buildBucket({ name: 'bucket-2' });
    mockApi('get', '/buckets', { buckets: [bucket1, bucket2] });
    mockBucketList('bucket-1', {
      '': {
        folders: ['folder1/'],
        files: [
          buildS3Object({
            key: 'objectA',
            size: 1,
            storageClass: 'STANDARD',
          }),
        ],
      },
      'folder1/': {
        folders: [],
        files: [
          buildS3Object({
            key: 'folder1/objectB',
            size: 1,
            storageClass: 'STANDARD',
          }),
          buildS3Object({
            key: 'folder1/objectC',
            size: 1,
            storageClass: 'STANDARD',
          }),
        ],
      },
    });
    mockApi('get', '/buckets/bucket-2/list', {
      folders: ['folder3/'],
      files: [
        buildS3Object({
          key: 'objectD',
          size: 1,
          storageClass: 'STANDARD',
        }),
      ],
    });
  });

  describe('Selecting items in the browser', () => {
    it('initially has an empty store', async () => {
      await renderAppAndWait();

      expect(await screen.findByText(/No items selected/)).toBeInTheDocument();
    });

    it('adds an item to the selection store when it is checked', async () => {
      await renderAppAndWait();
      await clickToFolder1();

      const objectBRow = screen.getByText('objectB').closest('tr');
      const objectBCheckbox = within(objectBRow).getByRole('checkbox');
      // click the checkbox
      await userEvent.click(objectBCheckbox);

      const selectionStore = await screen.findByTestId('selected-items');

      expect(await within(selectionStore).findByText('folder1/objectB')).toBeInTheDocument();
    });

    it('adds the parent folder to the selection store when all items are checked', async () => {
      await renderAppAndWait();
      await clickToFolder1();

      const objectBRow = screen.getByText('objectB').closest('tr');
      const objectBCheckbox = within(objectBRow).getByRole('checkbox');
      const objectCRow = screen.getByText('objectC').closest('tr');
      const objectCCheckbox = within(objectCRow).getByRole('checkbox');
      // click the checkboxes
      await userEvent.click(objectBCheckbox);
      await userEvent.click(objectCCheckbox);

      const selectionStore = await screen.findByTestId('selected-items');
      expect(await within(selectionStore).findByText('folder1/')).toBeInTheDocument();
    });

    it('displays a partial checkbox for the parent folder when some of its children are selected', async () => {
      await renderAppAndWait();
      await clickToFolder1();

      const objectBRow = screen.getByText('objectB').closest('tr');
      const objectBCheckbox = within(objectBRow).getByRole('checkbox');
      // click the checkbox
      await userEvent.click(objectBCheckbox);

      const selectAllCell = (await screen.findAllByRole('columnheader')).find((r) =>
        r.textContent.includes('Selection'),
      );
      const selectAllCheckBox = within(selectAllCell).getByRole('checkbox');
      expect((selectAllCheckBox as HTMLInputElement).indeterminate).toBe(true);
    });

    it('selects entire level when select all button is checked', async () => {
      await renderAppAndWait();
      await clickToFolder1();

      const selectAllCell = (await screen.findAllByRole('columnheader')).find((r) =>
        r.textContent.includes('Selection'),
      );
      const selectAllCheckBox = within(selectAllCell).getByRole('checkbox');

      await userEvent.click(selectAllCheckBox);

      const selectionStore = await screen.findByTestId('selected-items');
      expect(await within(selectionStore).findByText('folder1/')).toBeInTheDocument();
    });

    it('allows for selections across buckets', async () => {
      await renderAppAndWait();
      await clickToFolder1();

      const objectBRow = screen.getByText('objectB').closest('tr');
      const objectBCheckbox = within(objectBRow).getByRole('checkbox');
      // click the checkbox
      await userEvent.click(objectBCheckbox);

      // Navigate back to all buckets
      await userEvent.click(await screen.findByRole('link', { name: 'All Buckets' }));
      // Navigate to second bucket
      expect(await screen.findByRole('heading', { name: /S3 Buckets/ })).toBeInTheDocument();
      await userEvent.click(screen.getByRole('link', { name: 'bucket-2' }));
      await screen.findByText('objectD');
      const objectDRow = screen.getByText('objectD').closest('tr');
      const objectDCheckbox = within(objectDRow).getByRole('checkbox');
      // click the checkbox
      await userEvent.click(objectDCheckbox);

      const selectionStore = await screen.findByTestId('selected-items');
      expect(await within(selectionStore).findByText('bucket-1')).toBeInTheDocument();
      expect(await within(selectionStore).findByText('folder1/objectB')).toBeInTheDocument();
      expect(await within(selectionStore).findByText('bucket-2')).toBeInTheDocument();
      expect(await within(selectionStore).findByText('objectD')).toBeInTheDocument();
    });

    it('does not allow user to select entire bucket by adding objects one by one', async () => {
      await renderAppAndWait();
      await userEvent.click(await screen.findByRole('link', { name: 'bucket-2' }));
      await screen.findByText('folder3');
      const objectDRow = screen.getByText('objectD').closest('tr');
      const objectDCheckbox = within(objectDRow).getByRole('checkbox');
      const folder3Row = screen.getByText('folder3').closest('tr');
      const folder3Checkbox = within(folder3Row).getByRole('checkbox');
      await userEvent.click(objectDCheckbox);
      await userEvent.click(folder3Checkbox); // will not be selected

      const selectionStore = await screen.findByTestId('selected-items');
      expect(await within(selectionStore).findByText('bucket-2')).toBeInTheDocument();
      expect(await within(selectionStore).findByText(/objectD/)).toBeInTheDocument();

      expect(objectDCheckbox).toBeChecked();
      expect(await within(folder3Row).findByRole('checkbox')).not.toBeChecked();
    });

    it('does not allow user to select entire bucket by clicking select all on bucket root', async () => {
      await renderAppAndWait();
      await userEvent.click(await screen.findByRole('link', { name: 'bucket-2' }));
      const selectAllCell = (await screen.findAllByRole('columnheader')).find((r) =>
        r.textContent.includes('Selection'),
      );
      const selectAllCheckBox = within(selectAllCell).getByRole('checkbox');
      await userEvent.click(selectAllCheckBox);

      expect(await within(selectAllCell).findByRole('checkbox')).not.toBeChecked();
    });

    it('when a folder is selected and a child is then deselected, the folder is removed from the store and the other children are added', async () => {
      await renderAppAndWait();
      // add folder1/
      await userEvent.click(await screen.findByRole('link', { name: 'bucket-1' }));
      await screen.findByText('folder1');
      const folder1Row = screen.getByText('folder1').closest('tr');
      const folder1Checkbox = within(folder1Row).getByRole('checkbox');
      await userEvent.click(folder1Checkbox);

      const selectionStore = await screen.findByTestId('selected-items');
      expect(await within(selectionStore).findByText('folder1/')).toBeInTheDocument();

      // remove a child of folder1/
      await userEvent.click(screen.getByRole('link', { name: 'folder1' }));
      await screen.findByText('objectB');
      const objectBRow = screen.getByText('objectB').closest('tr');
      const objectBCheckbox = within(objectBRow).getByRole('checkbox');
      await userEvent.click(objectBCheckbox);

      expect(await within(selectionStore).findByText('folder1/objectC')).toBeInTheDocument();
    });

    it('clears the selection store when the button is clicked', async () => {
      await renderAppAndWait();
      await clickToFolder1();
      // add objectB
      await screen.findByText('objectB');
      const objectBRow = screen.getByText('objectB').closest('tr');
      const objectBCheckbox = within(objectBRow).getByRole('checkbox');
      await userEvent.click(objectBCheckbox);

      // reset selection
      const selectionStore = await screen.findByTestId('selected-items');
      expect(await within(selectionStore).findByText('folder1/objectB')).toBeInTheDocument();
      await userEvent.click(
        within(selectionStore).getByRole('button', { name: 'Reset Selection' }),
      );

      expect(await screen.findByText(/No items selected/)).toBeInTheDocument();
    });

    it('only allows exports when there is at least one item selected', async () => {
      await renderAppAndWait();
      await clickToFolder1();

      // Initially disabled
      const selectionStore = await screen.findByTestId('selected-items');
      const exportButton = within(selectionStore).getByRole('button', {
        name: 'Export Selection to CSV',
      });
      expect(exportButton).toBeDisabled();
      // add objectB
      await screen.findByText('objectB');
      const objectBRow = screen.getByText('objectB').closest('tr');
      const objectBCheckbox = within(objectBRow).getByRole('checkbox');
      await userEvent.click(objectBCheckbox);

      expect(await within(selectionStore).findByText('folder1/objectB')).toBeInTheDocument();
      expect(exportButton).toBeEnabled();
    });
  });
});
