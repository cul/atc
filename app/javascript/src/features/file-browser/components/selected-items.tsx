import { useSelectedItemsStore } from '@/stores/selected-items-store';

const SelectedItems = () => {
  const { buckets, reset } = useSelectedItemsStore();
  // const folders = items.filter((item) => item.type === 'folder');
  // const files = items.filter((item) => item.type === 'files');
  // TODO:
  // - if the only selected item is '/', then the whole bucket is selected
  // - add button to export
  // - make collapsable
  // - make it a bar (style it in general :3 )

  return (
    <div className="border border-primary">
      <button onClick={() => reset()}>reset selection</button>
      {buckets.map((bucket, i) => (
        <div key={`bucket${i}`}>
          {bucket.bucketName}
          folders:
          <ul>
            {[...bucket.folders].map((folder, j) => (
              <li key={`folder${j}`}>{folder}</li>
            ))}
          </ul>
          files:
          <ul>
            {[...bucket.objects].map((object, j) => (
              <li key={`object${j}`}>{object}</li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
};

export default SelectedItems;
