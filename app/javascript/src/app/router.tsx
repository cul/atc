import { useMemo } from 'react';
import { QueryClient, useQueryClient } from '@tanstack/react-query';
import { createBrowserRouter, LoaderFunction, ActionFunction, redirect } from 'react-router';
import { RouterProvider } from 'react-router/dom';
import { Spinner } from 'react-bootstrap';
import MainLayout from '@/components/layouts/main-layout';
import { RouteErrorFallback } from '@/components/errors/route-error';

interface RouteModule {
  default: React.ComponentType;
  clientLoader?: (queryClient: QueryClient) => LoaderFunction;
  clientAction?: (queryClient: QueryClient) => ActionFunction;
  [key: string]: unknown;
}

// Convert a module with clientLoader/clientAction into a route object.
// This allows loaders/actions to access the QueryClient for prefetching data
const convert = (queryClient: QueryClient) => (m: RouteModule) => {
  const { clientLoader, clientAction, default: Component, ...rest } = m;
  return {
    ...rest,
    loader: clientLoader?.(queryClient),
    action: clientAction?.(queryClient),
    Component,
  };
};

export const createAppRouter = (queryClient: QueryClient) =>
  createBrowserRouter([
    {
      hydrateFallbackElement: <Spinner animation="border" role="status" />,
      errorElement: <RouteErrorFallback />,
      children: [
        {
          index: true,
          loader: () => redirect('/browse/buckets'),
        },
        {
          path: 'csv_exports',
          children: [
            {
              index: true,
              lazy: () => import('./routes/csv-exports').then(convert(queryClient)),
            },
          ],
        },
        {
          path: 'browse',
          children: [
            {
              index: true,
              loader: () => redirect('/browse/buckets'),
            },
            {
              Component: MainLayout,
              path: 'buckets',
              children: [
                {
                  index: true,
                  lazy: () => import('./routes/buckets').then(convert(queryClient)),
                },
                {
                  path: ':bucketName',
                  lazy: () => import('./routes/bucket-contents').then(convert(queryClient)),
                },
                {
                  path: ':bucketName/object-details',
                  lazy: () => import('./routes/object-details').then(convert(queryClient)),
                  // This route uses useSuspenseQuery, so we want to ensure any errors are caught by the route error boundary
                  errorElement: (
                    <RouteErrorFallback errorMessage="Error loading object details. Please try again." />
                  ),
                },
              ],
            },
          ],
        },
        {
          path: '*',
          lazy: () => import('./routes/not-found').then(convert(queryClient)),
        },
      ],
    },
  ]);

export const AppRouter = () => {
  const queryClient = useQueryClient();

  const router = useMemo(() => createAppRouter(queryClient), [queryClient]);

  return <RouterProvider router={router} />;
};
