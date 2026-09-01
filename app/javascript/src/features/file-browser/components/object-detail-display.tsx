import { useMemo } from 'react';
import { useParams, useSearchParams } from 'react-router';
import {
  formatSize,
  formatLastModified,
  capitalizeStr,
  extractName,
  extractFileExtension,
} from '../utils/format-utils';
import { useObjectDetailsSuspenseQuery } from '../api/get-object-details';
import DetailField from '../../../components/ui/detail-field';

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

const ObjectDetailDisplay = () => {
  const params = useParams();
  const bucketName = params.bucketName as string;
  const [searchParams] = useSearchParams();
  const key = searchParams.get('prefix') ?? '';

  const query = useObjectDetailsSuspenseQuery({ bucket: bucketName, key });
  const objectDetails = query.data;

  const { size, lastModified, storageClass, archiveStatus, restoreStatus } = objectDetails;

  const isNonStandard = storageClass !== 'STANDARD';
  const fileName = useMemo(() => extractName(objectDetails.key), [objectDetails.key]);

  return (
    <div className="pt-2">
      <h4 className="mb-3">{fileName}</h4>

      <section className="border rounded p-3 mb-4">
        <h5 className="mb-3">Object Overview</h5>

        <dl className="mb-0">
          <DetailField label="Key" value={objectDetails.key} />
          <DetailField label="Type" value={extractFileExtension(fileName)} />
          <DetailField label="Size" value={formatSize(size)} />
          <DetailField label="Last modified" value={formatLastModified(lastModified)} />
        </dl>
      </section>

      <section className="border rounded p-3">
        <h5 className="mb-3">Storage Details</h5>

        <dl className="mb-0">
          <DetailField label="Storage class" value={capitalizeStr(storageClass)} />

          {isNonStandard && (
            <>
              <DetailField label="Access tier" value={displayAccessTierLabel(archiveStatus)} />
              <DetailField
                label="Retrieval time"
                value={displayRetrievalTime(archiveStatus)}
                hint="Retrieval times depend on the access tier of an object."
              />
              <DetailField
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
