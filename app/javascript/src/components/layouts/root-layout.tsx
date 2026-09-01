import { Outlet } from 'react-router';
import { Notifications } from '../ui/notifications/notifications';
import NavBar from '../ui/nav-bar';

// We need to render the Notifications with in the router provider so that
// Link elements function
const RootLayout = () => (
  <>
    <NavBar />
    <Notifications />
    <Outlet />
  </>
);

export default RootLayout;
