import { Link } from 'react-router';
import Breadcrumb from 'react-bootstrap/Breadcrumb';

interface BreadcrumbsProps {
  bucketName?: string;
  prefix?: string;
}

const buildSegments = (
  bucketName?: string,
  prefix?: string,
) => {
  // TODO: create breadcrumb segments based on bucketName and prefix
  // All segments should link to the appropriate route except the last one which is the current page
  console.log('Building breadcrumb segments for', bucketName, prefix);
};

const Breadcrumbs = ({ bucketName, prefix }: BreadcrumbsProps) => {
  const segments = buildSegments(bucketName, prefix);

  return (
    <Breadcrumb>
      <Breadcrumb.Item linkAs={Link} linkProps={{ to: '/' }}>
        Buckets
      </Breadcrumb.Item>
    </Breadcrumb>
  )
};

export default Breadcrumbs;