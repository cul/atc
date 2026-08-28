import { Accordion, Card, Col, Row, useAccordionButton } from 'react-bootstrap';

import { api } from '@/lib/api-client';
import { useSelectedItemsStore } from '@/stores/selected-items-store';
import {
  csvExportReqBody,
  getBucketSelectionCount,
  notifyNewCsvExport,
} from '../utils/selection-utils';

// I would prefer to keep this header component in the same file as the Selected Items accordion, because
// it is tightly coupled to that component, won't be reused, and cannot be inlined in SelectedItems because
// it calls the useAccordionButton hook
const SelectionBoxHeader = ({ eventKey, disabled }: { eventKey: string; disabled: boolean }) => {
  const { buckets, reset } = useSelectedItemsStore();
  const expandSelection = useAccordionButton(eventKey);
  const exportSelection = async () => {
    const response = await api.post('/csv_exports', csvExportReqBody(buckets));
    reset();
    notifyNewCsvExport((response as { id: string })?.id);
  };

  return (
    <div className="d-flex gap-3">
      <button type="button" className="btn btn-sm btn-outline-dark" onClick={expandSelection}>
        Show Selection
      </button>
      <button
        type="button"
        className="btn btn-sm btn-outline-success"
        disabled={disabled}
        onClick={exportSelection}
      >
        Export Selection to CSV
      </button>
    </div>
  );
};

const SelectedItems = () => {
  const { buckets, reset } = useSelectedItemsStore();

  return (
    <Accordion data-testid="selected-items" className="my-2">
      <Card>
        <Card.Header>
          <SelectionBoxHeader eventKey="0" disabled={buckets.length === 0} />
        </Card.Header>
        <Accordion.Collapse eventKey="0">
          <div className="p-3" style={{ fontSize: '.9em', maxHeight: '50vh', overflowY: 'auto' }}>
            {buckets.length === 0 && (
              <span className="text-secondary fst-italic">No items selected.</span>
            )}
            {buckets.length > 0 && (
              <>
                <button className="btn btn-danger btn-sm mb-3" onClick={() => reset()}>
                  Reset Selection
                </button>
              </>
            )}
            {buckets.map((bucket, i) => (
              <div key={`bucket${i}`} className="bg-light rounded-3 p-2 my-1">
                Selected items in bucket <span className="fw-bold">{bucket.bucketName}</span> (
                {getBucketSelectionCount(bucket)}):
                <Row>
                  <Col xs={6}>
                    Folders:
                    <ul>
                      {[...bucket.folders].map((folder, j) => (
                        <li key={`folder${j}`}>{folder}</li>
                      ))}
                    </ul>
                  </Col>
                  <Col xs={6} className="border-start border-secondary">
                    files:
                    <ul>
                      {[...bucket.files].map((file, j) => (
                        <li key={`file${j}`}>{file}</li>
                      ))}
                    </ul>
                  </Col>
                </Row>
              </div>
            ))}
          </div>
        </Accordion.Collapse>
      </Card>
    </Accordion>
  );
};

export default SelectedItems;
