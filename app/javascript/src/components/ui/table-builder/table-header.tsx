import { flexRender, Header, HeaderGroup } from '@tanstack/react-table';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faSort, faSortUp, faSortDown } from '@fortawesome/free-solid-svg-icons';

interface TableHeaderProps<T> {
  headerGroup: HeaderGroup<T>;
}

function TableHeader<T>({ headerGroup }: TableHeaderProps<T>) {
  const renderSortingIcon = (sortDirection: 'asc' | 'desc' | null) => {
    const sharedClassNames = 'ms-2 flex-shrink-0 mt-1';

    if (sortDirection === 'asc') {
      return <FontAwesomeIcon icon={faSortUp} className={sharedClassNames} />;
    }
    if (sortDirection === 'desc') {
      return <FontAwesomeIcon icon={faSortDown} className={sharedClassNames} />;
    }
    return <FontAwesomeIcon icon={faSort} className={sharedClassNames} />;
  };

  const createColumnHeader = (header: Header<T, unknown>) => {
    if (header.isPlaceholder) return null;

    const sharedClassNames = 'fw-semibold d-inline-flex m-0 p-0 align-items-start text-start';
    const headerText = flexRender(header.column.columnDef.header, header.getContext());

    if (header.column.getCanSort()) {
      return (
        <button
          type="button"
          className={`btn ${sharedClassNames}`}
          onClick={header.column.getToggleSortingHandler()}
        >
          {headerText}
          {renderSortingIcon(header.column.getIsSorted() || null)}
        </button>
      );
    }

    return <div className={sharedClassNames}>{headerText}</div>;
  };

  return (
    <thead>
      <tr key={headerGroup.id}>
        {headerGroup.headers.map((header) => (
          <th
            key={header.id}
            className={`${header.column.getIsSorted() && 'bg-primary bg-opacity-25'} text-${header.column.columnDef.meta?.textAlign}`}
          >
            {createColumnHeader(header)}
          </th>
        ))}
      </tr>
    </thead>
  );
}

export default TableHeader;
