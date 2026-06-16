import { ToastContainer } from 'react-bootstrap';
import { useNotifications } from '@/stores/notifications-store';
import { Notification } from './notification';

export const Notifications = () => {
  const { notifications, dismissNotification } = useNotifications();

  return (
    <ToastContainer className="p-3 top-15 end-0">
      {notifications.map((notification) => (
        <Notification
          key={notification.id}
          notification={notification}
          onDismiss={dismissNotification}
        />
      ))}
    </ToastContainer>
  );
};
