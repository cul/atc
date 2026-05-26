import { useNotifications } from '@/stores/notifications-store';
import { ErrorData } from '@/types/api';

const BASE_URL = '/api';

// ? Maybe we should rely on the backend to provide more user-friendly error messages
const AWS_ERROR_MESSAGES: Record<string, string> = {
  AccessDenied:
    'You do not have permission to access this resource. The AWS credentials may have been rotated.',
};

const isErrorData = (data: unknown): data is ErrorData =>
  typeof data === 'object' &&
  data !== null &&
  'error' in data &&
  typeof (data as Record<string, unknown>).error === 'string';

const notifyError = (status: number, raw: unknown) => {
  const data = isErrorData(raw) ? raw : null;
  const code = data?.code;
  const error = data?.error ?? 'An unexpected error occurred.';

  useNotifications.getState().addNotification({
    type: 'error',
    title: code ? `AWS ${status} Error: ${code})` : `${status} Error`,
    message: code ? (AWS_ERROR_MESSAGES[code] ?? error) : error,
  });
};

type RequestOptions = RequestInit & { silent?: boolean };

async function request<T>(endpoint: string, options: RequestOptions = {}): Promise<T> {
  const { silent, ...fetchOptions } = options;

  const response = await fetch(`${BASE_URL}${endpoint}`, {
    ...fetchOptions,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...fetchOptions?.headers,
    },
    credentials: 'include',
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => null);
    if (!silent) notifyError(response.status, errorData);

    // Throw the parsed error data so React Query can access it
    throw new Error(response.statusText || `HTTP ${response.status}`);
  }

  return response.json();
}

export const api = {
  get: <T>(endpoint: string, options?: Omit<RequestOptions, 'method'>) =>
    request<T>(endpoint, { ...options, method: 'GET' }),
};
