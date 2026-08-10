import { api } from '@/lib/api-client';
import { BucketSelection, useSelectedItemsStore } from '@/stores/selected-items-store';
import { Accordion, Card, Col, Row, useAccordionButton } from 'react-bootstrap';

type CsvExportBody = {
  bucket: string;
  files: string[];
  directories: string[];
};

const csvExportReqBody = (buckets: BucketSelection[]): CsvExportBody[] => {
  return buckets.map((bucket) => {
    return {
      bucket: bucket.bucketName,
      files: [...bucket.objects],
      directories: [...bucket.folders],
    };
  });
};

function SelectionBoxActions({ eventKey, disabled }: { eventKey: string; disabled: boolean }) {
  const { buckets } = useSelectedItemsStore();
  const expandSelection = useAccordionButton(eventKey);
  const exportSelection = async () => {
    console.log('Export selection!');
    console.log(`${getFullSelectionCount(buckets)} items selected for export.`);
    const response = await api.post('/api/csv_exports', csvExportReqBody(buckets));
    console.log('response is:');
    console.log(response);
    // response contains ID of initiated export
    // display pop up with link to export view page
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
}

const getFullSelectionCount = (buckets: BucketSelection[]) => {
  let count = 0;
  buckets.forEach((bucket) => {
    count += [...bucket.folders].length;
    count += [...bucket.objects].length;
  });
  return count;
};

const getBucketSelectionCount = (bucket: BucketSelection) => {
  let count = 0;
  count += [...bucket.folders].length;
  count += [...bucket.objects].length;
  return count > 1 ? `${count} selections` : `1 selection`;
};

const SelectedItems = () => {
  const { buckets, reset } = useSelectedItemsStore();

  return (
    <Accordion className="my-2">
      <Card>
        <Card.Header>
          <SelectionBoxActions eventKey="0" disabled={buckets.length === 0} />
        </Card.Header>
        <Accordion.Collapse eventKey="0">
          <div className="p-3" style={{ fontSize: '.9em' }}>
            {buckets.length === 0 && (
              <span className="text-secondary fst-italic">No items selected.</span>
            )}
            {buckets.length > 0 && (
              <>
                <button className="btn btn-danger btn-sm mb-3" onClick={() => reset()}>
                  reset selection
                </button>
              </>
            )}
            {buckets.map((bucket, i) => (
              <div key={`bucket${i}`} className="bg-light rounded-3 p-2 my-1">
                Selected items in bucket <span className="fw-bold">{bucket.bucketName}</span> (
                {getBucketSelectionCount(bucket)}):
                <Row>
                  {bucket.folders.has('/') ? (
                    <span className="text-success">Entire bucket is selected</span>
                  ) : (
                    <>
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
                          {[...bucket.objects].map((object, j) => (
                            <li key={`object${j}`}>{object}</li>
                          ))}
                        </ul>
                      </Col>
                    </>
                  )}
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
