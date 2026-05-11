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
  const segments = [
    { label: 'All Buckets', to: '/' },
  ];
 
  if (!bucketName) return segments;
 
  const bucketPath = `/buckets/${encodeURIComponent(bucketName)}`;
 
  segments.push({
    label: bucketName,
    to: bucketPath,
  });
 
  if (!prefix) return segments;
 
  const parts = prefix.split('/').filter(Boolean); // Remove empty parts caused by trailing slash
  let finalPath = '';
 
  for (const part of parts) {
    finalPath += `${encodeURIComponent(part)}/`;
    segments.push({
      label: part,
      to: `${bucketPath}?prefix=${finalPath}`,
    });
  }
 
  return segments;
};

const Breadcrumbs = ({ bucketName, prefix }: BreadcrumbsProps) => {
  const segments = buildSegments(bucketName, prefix);

  return (
    <Breadcrumb>
    {segments.map((segment, index) => (
      <Breadcrumb.Item
        key={index}
        linkAs={Link}
        linkProps={{ to: segment.to }}
        active={index === segments.length - 1}
      >
        {segment.label}
      </Breadcrumb.Item>
    ))}
  </Breadcrumb>
  );
};

export default Breadcrumbs;