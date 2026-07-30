import { createRoot } from 'react-dom/client';
import App from '../src/app/App';

const s3BrowserAppElement = document.getElementById('s3-browser-app');
if (!s3BrowserAppElement) throw new Error('S3 Browser app root element not found');

const s3BrowserRoot = createRoot(s3BrowserAppElement);
s3BrowserRoot.render(<App />);

