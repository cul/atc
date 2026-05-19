export const formatSize = (sizeInBytes: number) => {
  const units = ['B', 'kB', 'MB', 'GB', 'TB'];
  let size = sizeInBytes;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  return unitIndex === 0 ? `${size} ${units[unitIndex]}` : `${size.toFixed(2)} ${units[unitIndex]}`;
}

export const capitalizeStr = (str: string) => {
  return str.toLowerCase()
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

export const extractName = (fullPath: string): string => {
  const trimmed = fullPath.endsWith('/') ? fullPath.slice(0, -1) : fullPath;
  const lastSlash = trimmed.lastIndexOf('/');
  return lastSlash === -1 ? trimmed : trimmed.slice(lastSlash + 1);
};