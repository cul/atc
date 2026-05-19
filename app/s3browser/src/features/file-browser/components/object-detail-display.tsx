import { ObjectDetails } from '@/types/api';
import { formatSize, capitalizeStr, extractName } from '../utils/format-utils';

type ObjectDetailDisplayProps = {
  objectDetails: ObjectDetails;
};

const ObjectDetailDisplay = ({ objectDetails }: ObjectDetailDisplayProps) => {
  const displayRetrievalTime = () => {
    if (objectDetails.archiveStatus === 'ARCHIVE_ACCESS') {
      return '5 hours';
    } else if (objectDetails.archiveStatus === 'DEEP_ARCHIVE_ACCESS') {
      return '12 hours';
    }
    return 'Milliseconds (instant access)';
  }

  return (
    <div className="pt-2">
      {/* TODO: Make this less verbose/ DRY */}
      <h4>{extractName(objectDetails.key)}</h4>
      <div className="border rounded p-3 mb-4 mt-3">
        <h5 className="mb-3">Object overview</h5>

        <div className="section mb-3">
          <p className='m-0'><strong>Key</strong></p>
          <p className="m-0">{objectDetails.key}</p>
        </div>

        <div className="section mb-3">
          <p className='m-0'><strong>Content Type</strong></p>
          <p className="m-0">{objectDetails.contentType}</p>
        </div>

        <div className="section mb-3">
          <p className='m-0'><strong>Size</strong></p>
          <p className="m-0">{formatSize(objectDetails.size)}</p>
        </div>

        <div className="section mb-3">
          <p className='m-0'><strong>Last Modified</strong></p>
          <p className="m-0">{new Date(objectDetails.lastModified).toLocaleString()}</p>
        </div>
      </div>

      <div className="border rounded p-3">
        <h5 className="mb-3">Storage class</h5>
        <div className="section mb-3">
          <p className='m-0'><strong>Storage Class</strong></p>
          <p className="m-0">{capitalizeStr(objectDetails.storageClass)}</p>
        </div>

        {/* For non-standard storage classes, we display information about access tiers and retrieval time */}
        {objectDetails.storageClass !== 'STANDARD' && (
          <>
            <div className="section mb-3">
              <p className='m-0'><strong>Access Tier</strong></p>
              {/* If storage class is Intelligent Tiering and archiveStatus is null, it means the object is in one of the frequent access, infrequent access, or archive instant access tiers */}
              <p className="m-0">{objectDetails.archiveStatus ? capitalizeStr(objectDetails.archiveStatus) : 'Frequent Access, Infrequent Access, or Archive Instant Access tier'}</p>
            </div>

            <div className="section mb-3">
              <p className='m-0'><strong>Retrieval time</strong></p>
              <small className="text-muted m-0">Retrieval times depend on the access tier of an object.</small>
              <p className="m-0">{displayRetrievalTime()}</p>
            </div>
            <div className="section mb-3">
              <p className='m-0'><strong>Restoration status</strong></p>
              <p className="m-0">{objectDetails.restoreStatus ? capitalizeStr(objectDetails.restoreStatus) : 'N/A'}</p>
            </div>
          </>
        )}
      </div>
    </div>
  )
};

export default ObjectDetailDisplay;