// Prefix has to end with '/' for S3 ListObjectsV2 to treat it as a folder
const normalizePrefix = (raw: string): string => {
  if (!raw) return '';
  return raw.endsWith('/') ? raw : `${raw}/`;
};

const formatSize = (sizeInBytes: number) => {
  const units = ['B', 'kB', 'MB', 'GB', 'TB'];
  let size = sizeInBytes;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  return unitIndex === 0 ? `${size} ${units[unitIndex]}` : `${size.toFixed(2)} ${units[unitIndex]}`;
};

const capitalizeStr = (str: string) => {
  return str
    .toLowerCase()
    .split('_')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
};

const extractName = (fullPath: string): string => {
  const trimmed = fullPath.endsWith('/') ? fullPath.slice(0, -1) : fullPath;
  const lastSlash = trimmed.lastIndexOf('/');
  return lastSlash === -1 ? trimmed : trimmed.slice(lastSlash + 1);
};

const formatLastModified = (dateString: string): string => {
  const date = new Date(dateString);
  const pad = (n: number) => n.toString().padStart(2, '0');

  return (
    `${date.toLocaleString('en-US', { month: 'long' })} ${date.getDate()}, ${date.getFullYear()}, ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
};

const extractFileExtension = (fileName: string) => {
  const parts = fileName.split('.');
  return parts.length > 1 ? parts.pop() : 'unknown';
};

export {
  formatSize,
  capitalizeStr,
  extractName,
  formatLastModified,
  extractFileExtension,
  normalizePrefix,
};
