import { useMemo } from 'react';
import { ObjectDetails } from '@/types/api';
import {
  formatSize,
  formatLastModified,
  capitalizeStr,
  extractName,
  extractFileExtension,
} from '../utils/format-utils';
import ObjectDetailField from './object-detail-field';

const displayRetrievalTime = (archiveStatus: string | null) => {
  switch (archiveStatus) {
    case 'ARCHIVE_ACCESS':
      return '5 hours';
    case 'DEEP_ARCHIVE_ACCESS':
      return '12 hours';
    default:
      return 'Milliseconds (instant access)';
  }
};

const displayAccessTierLabel = (archiveStatus: string | null) =>
  archiveStatus
    ? capitalizeStr(archiveStatus)
    : 'Frequent Access, Infrequent Access, or Archive Instant Access tier';

type ObjectDetailDisplayProps = {
  objectDetails: ObjectDetails;
};

const ObjectDetailDisplay = ({ objectDetails }: ObjectDetailDisplayProps) => {
  const { key, size, lastModified, storageClass, archiveStatus, restoreStatus } = objectDetails;

  const isNonStandard = storageClass !== 'STANDARD';
  const fileName = useMemo(() => extractName(key), [key]);

  return (
    <div className="pt-2">
      <h4 className="mb-3">{fileName}</h4>

      <section className="border rounded p-3 mb-4">
        <h5 className="mb-3">Object Overview</h5>

        <dl className="mb-0">
          <ObjectDetailField label="Key" value={objectDetails.key} />
          <ObjectDetailField label="Type" value={extractFileExtension(fileName)} />
          <ObjectDetailField label="Size" value={formatSize(size)} />
          <ObjectDetailField label="Last modified" value={formatLastModified(lastModified)} />
        </dl>
      </section>

      <section className="border rounded p-3">
        <h5 className="mb-3">Storage Details</h5>

        <dl className="mb-0">
          <ObjectDetailField label="Storage class" value={capitalizeStr(storageClass)} />

          {isNonStandard && (
            <>
              <ObjectDetailField
                label="Access tier"
                value={displayAccessTierLabel(archiveStatus)}
              />
              <ObjectDetailField
                label="Retrieval time"
                value={displayRetrievalTime(archiveStatus)}
                hint="Retrieval times depend on the access tier of an object."
              />
              <ObjectDetailField
                label="Restoration status"
                value={
                  restoreStatus
                    ? capitalizeStr(restoreStatus)
                    : 'No restoration currently in progress'
                }
              />
            </>
          )}
        </dl>
      </section>
    </div>
  );
};

export default ObjectDetailDisplay;
