import { ErrorData } from '@/types/api';

/**
 Structured error class for API responses outside the 2xx range.

 Throwing this instead of a plain error lets any downstream code
 (React Query `onError`, error boundaries) inspect the HTTP status 
 and the parsed response body without having to re-parse anything.
*/
export class ApiError extends Error {
  constructor(
    public status: number,
    public statusText: string,
    public data: ErrorData | null,
  ) {
    super((data?.error ?? statusText) || `HTTP ${status}`);
    this.name = 'ApiError';
  }

  get isServerError(): boolean {
    return this.status >= 500;
  }
}
