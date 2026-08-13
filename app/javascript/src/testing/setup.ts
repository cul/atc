import '@testing-library/jest-dom/vitest';
import { server } from './mock-api';
import { useSelectedItemsStore } from '@/stores/selected-items-store';

beforeAll(() => {
  server.listen({ onUnhandledRequest: 'warn' });
});

afterEach(() => {
  server.resetHandlers();
  useSelectedItemsStore.getState().reset();
});

afterAll(() => {
  server.close();
});
