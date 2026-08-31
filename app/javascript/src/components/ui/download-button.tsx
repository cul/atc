import { useState } from 'react';
import { Button } from 'react-bootstrap';
import { parseErrorBody, notifyError } from '@/lib/api-client';

interface DownloadButtonProps extends React.ComponentPropsWithRef<'button'> {
  endpoint: string;
  defaultFilename?: string;
  styles?: string;
  variant?: string;
}

// A button that is used to download a file from an API endpoint
// and optionally render an error notification when appropriate.
// Adapted from: https://cheeger.com/general/2025/08/29/react-download-file-within-handler.html
const DownloadButton = ({ endpoint, defaultFilename, styles, variant }: DownloadButtonProps) => {
  const [isDownloading, setIsDownloading] = useState(false);

  const handleDownload = async () => {
    setIsDownloading(true);

    const response = await fetch(endpoint, {
      credentials: 'include',
    });

    if (!response.ok) {
      const errorData = await parseErrorBody(response);
      notifyError(response.status, errorData);
    }

    const blob = await response.blob();
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    const filename =
      response.headers.get('Content-Disposition')?.match(/filename="?([^"]+)"?/)?.[1] ??
      defaultFilename;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);

    setIsDownloading(false);
  };

  return (
    <Button onClick={handleDownload} disabled={isDownloading} className={styles} variant={variant}>
      Download
    </Button>
  );
};

export default DownloadButton;
