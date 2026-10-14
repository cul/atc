import React from 'react';
import {
  render as rtlRender,
  screen,
  waitForElementToBeRemoved,
  waitFor,
  within,
} from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { LoaderFunction, RouteObject, RouterProvider, createMemoryRouter } from 'react-router';
import { Notifications } from '@/components/ui/notifications/notifications';

export {
  buildBucket,
  buildObjectDetails,
  buildS3Object,
  buildS3Objects,
  buildBucketContents,
} from './data-generators';
export { mockApi } from './mock-api';

const createTestQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
        gcTime: Infinity,
      },
    },
  });

interface RenderAppOptions {
  url?: string;
  path?: string; // parent
  loaderFn?: (queryClient: QueryClient) => LoaderFunction;
  children?: RouteObject[]; // for nested routes and tests rendered in layouts with an Outlet
  [key: string]: unknown;
}

const buildRoutedRender = (
  ui: React.ReactElement,
  {
    url = '/', // simulated browser location to navigate to (e.g. '/users/janedoe/edit')
    path, // parent route - route pattern React Router uses for matching and resolving params (e.g. '/users/:userUid/edit')
    loaderFn = undefined,
    children = undefined,
    ...renderOptions
  }: RenderAppOptions = {},
) => {
  const queryClient = createTestQueryClient();
  const routePath = path ?? url; // defaults to url — only pass path for parameterized routes

  const isRoot = url === '/';
  const router = createMemoryRouter(
    [
      {
        path: routePath,
        element: ui,
        loader: loaderFn ? loaderFn(queryClient) : undefined,
        children: children,
        hydrateFallbackElement: <div>Hydration Fallback (test)...</div>,
      },
    ],
    {
      initialEntries: isRoot ? ['/'] : ['/', url],
      initialIndex: isRoot ? 0 : 1,
    },
  );

  const result = rtlRender(
    <QueryClientProvider client={queryClient}>
      <Notifications />
      <RouterProvider router={router} />
    </QueryClientProvider>,
    renderOptions,
  );

  return { result, router, queryClient };
};

// Default helper - renders a component inside a QueryClient + MemoryRouter
export const renderApp = async (ui: React.ReactElement, options: RenderAppOptions = {}) => {
  const { result } = buildRoutedRender(ui, options);
  return result;
};

// App + router - use for testing URLs (eg. navigation logic that modifies `?page=N` param).
export const renderAppWithRouter = async (
  ui: React.ReactElement,
  options: RenderAppOptions = {},
) => {
  const { result, router } = buildRoutedRender(ui, options);
  return { ...result, router };
};

export * from '@testing-library/react';
export { default as userEvent } from '@testing-library/user-event';
export { screen, waitForElementToBeRemoved, waitFor, within };
