import { Outlet } from 'react-router';
import { Notifications } from '../ui/notifications/notifications';

// We need to render the Notifications with in the router provider so that
// Link elements function
const RootLayout = () => (
  <>
    <Notifications />
    <Outlet />
  </>
);

export default RootLayout;
