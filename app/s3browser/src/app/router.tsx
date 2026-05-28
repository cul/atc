import { useMemo } from 'react';
import { QueryClient, useQueryClient } from '@tanstack/react-query';
import { createBrowserRouter, LoaderFunction, ActionFunction } from 'react-router';
import { RouterProvider } from 'react-router/dom';
import { Spinner } from 'react-bootstrap';
import MainLayout from '@/components/layouts/main-layout';

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
      children: [
        {
          index: true,
          Component: () => <div>This is the root of the React app.</div>,
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
            }
          ],
        },
      ],
    },
    {
      path: '*',
      lazy: () => import('./routes/not-found').then(convert(queryClient)),
    },
  ], {
    basename: '/browse',
  });

export const AppRouter = () => {
  const queryClient = useQueryClient();

  const router = useMemo(() => createAppRouter(queryClient), [queryClient]);

  return <RouterProvider router={router} />;
};