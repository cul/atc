import { useSelectedItemsStore } from '@/stores/selected-items-store';

const SelectedItems = () => {
  const { folders, objects, reset } = useSelectedItemsStore();
  // const folders = items.filter((item) => item.type === 'folder');
  // const files = items.filter((item) => item.type === 'files');

  return (
    <div className="border border-primary">
      <button onClick={() => reset()}>reset selection</button>
      <div>
        folders:
        <ul>
          {[...folders].map((folder, i) => (
            <li key={`folder${i}`}>{folder}</li>
          ))}
        </ul>
        files:
        <ul>
          {[...objects].map((object, i) => (
            <li key={`object${i}`}>{object}</li>
          ))}
        </ul>
      </div>
    </div>
  );
};

export default SelectedItems;
