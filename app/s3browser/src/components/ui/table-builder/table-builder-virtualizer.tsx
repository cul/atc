import { useState, useRef } from 'react'

import {
  getCoreRowModel,
  useReactTable,
  ColumnDef,
  getSortedRowModel,
  SortingState,
} from '@tanstack/react-table'
import { Table as BTable } from 'react-bootstrap'
import { useVirtualizer } from '@tanstack/react-virtual'

import TableHeader from './table-header'
import TableRow from './table-row'

interface TableBuilderVirtualizerProps<T> {
  data: T[]
  columns: ColumnDef<T>[]
  initialSorting?: SortingState
  maxHeight?: string | number
}

const DEFAULT_ROW_HEIGHT_PX = 45
const DEFAULT_OVERSCAN = 10 // Number of items to render above and below the visible area

// Virtualized variant of TableBuilder. Renders only the rows visible in the
// viewport (plus an overscan buffer), keeping DOM size constant regardless of
// dataset size. Use this for tables that may render large datasets.
function TableBuilderVirtualizer<T extends object>({
  data,
  columns,
  initialSorting = [],
  maxHeight = '70vh',
}: TableBuilderVirtualizerProps<T>) {
  const [sorting, setSorting] = useState<SortingState>(initialSorting)
  const parentRef = useRef<HTMLDivElement>(null)

  const table = useReactTable<T>({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    state: { sorting },
    getSortedRowModel: getSortedRowModel(),
    onSortingChange: setSorting,
  })

  const { rows } = table.getRowModel()

  const virtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => DEFAULT_ROW_HEIGHT_PX,
    overscan: DEFAULT_OVERSCAN,
  })

  const virtualItems = virtualizer.getVirtualItems()
  const totalSize = virtualizer.getTotalSize()

  // Padding used by spacer rows. Spacer rows trick the browser into rendering a scrollbar 
  // that reflects the full dataset size, even though we're only rendering a subset of rows in the DOM.
  const paddingTop = virtualItems.length > 0 ? virtualItems[0].start : 0
  const paddingBottom =
    virtualItems.length > 0
      ? totalSize - virtualItems[virtualItems.length - 1].end
      : 0

  return (
    <div
      ref={parentRef}
      style={{
        height: typeof maxHeight === 'number' ? `${maxHeight}px` : maxHeight,
        overflow: 'auto',
        position: 'relative',
      }}
    >
      <BTable striped bordered hover size="md" className="rounded-4 mb-0">
        {/* TODO: Fix the width of the header columns - as the user scrolls, sometimes the columns shift, depending on the content of the cells. */}
        {table.getHeaderGroups().map((headerGroup) => (
          <TableHeader key={headerGroup.id} headerGroup={headerGroup} />
        ))}
        <tbody>
          {rows.length === 0 && (
            <tr>
              <td colSpan={columns.length} className="text-center py-3">
                No entries found.
              </td>
            </tr>
          )}

          {paddingTop > 0 && (
            <tr aria-hidden="true">
              <td
                colSpan={columns.length}
                style={{ height: paddingTop, padding: 0, border: 0 }}
              />
            </tr>
          )}

          {virtualItems.map((virtualRow) => {
            const row = rows[virtualRow.index]
            return <TableRow row={row} key={row.id} />
          })}

          {paddingBottom > 0 && (
            <tr aria-hidden="true">
              <td
                colSpan={columns.length}
                style={{ height: paddingBottom, padding: 0, border: 0 }}
              />
            </tr>
          )}
        </tbody>
      </BTable>
    </div>
  )
}

export default TableBuilderVirtualizer