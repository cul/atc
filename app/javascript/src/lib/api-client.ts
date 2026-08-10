import { useNotifications } from '@/stores/notifications-store';
import { ErrorData } from '@/types/api';
import { ApiError } from './api-error';

export { ApiError };

const BASE_URL = '/api';

const isErrorData = (data: unknown): data is ErrorData =>
  typeof data === 'object' &&
  data !== null &&
  'error' in data &&
  typeof (data as Record<string, unknown>).error === 'string';

// Attempt to parse the response body as JSON
const parseErrorBody = async (response: Response): Promise<ErrorData | null> => {
  try {
    const json: unknown = await response.json();
    return isErrorData(json) ? json : null;
  } catch {
    return null;
  }
};

// Decide whether a toast should be shown for this particular failure.
// This is more flexible than a simple `silent` boolean because it allows for suppressing toasts
// for expected failure cases.
const shouldSilence = (silent: boolean | number[] | undefined, status: number): boolean => {
  if (silent === true) return true;
  if (Array.isArray(silent)) return silent.includes(status);

  return false;
};

const notifyError = (status: number, data: ErrorData | null) => {
  const message = data?.error ?? 'An unexpected error occurred.';

  useNotifications.getState().addNotification({
    type: 'error',
    title: `${status} Error`,
    message,
  });
};

type RequestOptions = RequestInit & {
  /**
    Controls whether error toasts are shown.
     - true - never show a toast
     - number[] - suppress toasts for these HTTP status codes only, eg. `[404, 500]`
     - undefined - always show a toast on failure (default)
    */
  silent?: boolean | number[];
};

async function request<T>(endpoint: string, options: RequestOptions = {}): Promise<T> {
  const { silent, ...fetchOptions } = options;

  const response = await fetch(`${BASE_URL}${endpoint}`, {
    ...fetchOptions,
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...fetchOptions?.headers,
    },
    credentials: 'include',
  });

  if (!response.ok) {
    const errorData = await parseErrorBody(response);

    if (!shouldSilence(silent, response.status)) {
      notifyError(response.status, errorData);
    }

    // Throw the parsed error data so React Query can access it
    throw new ApiError(response.status, response.statusText, errorData);
  }

  return response.json();
}

export const api = {
  get: <T>(endpoint: string, options?: Omit<RequestOptions, 'method'>) =>
    request<T>(endpoint, { ...options, method: 'GET' }),
  post: <T>(endpoint: string, data?: unknown, options?: Omit<RequestOptions, 'method'>) =>
    request<T>(endpoint, { ...options, method: 'POST', body: JSON.stringify(data) }),
};
