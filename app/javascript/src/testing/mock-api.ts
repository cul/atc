import { http, HttpResponse, JsonBodyType } from 'msw';
import { setupServer } from 'msw/node';

export const server = setupServer();

type HttpMethod = 'get';

// Register a mock API response for a single endpoint. Call once per endpoint per test.
// Overrides are cleared automatically by `server.resetHandlers()` in the global `afterEach`.
export const mockApi = (method: HttpMethod, path: string, body: JsonBodyType, status = 200) => {
  server.use(http[method](`api${path}`, () => HttpResponse.json(body, { status })));
};

// Allows us to mock API response for the /api/buckets/:bucketname/list/?prefix=... API
// at multiple different levels of a bucket based on the prefix URL search params.
// Used in tests where we navigate between levels.
export const mockBucketList = (bucket: string, prefixMap: Record<string, JsonBodyType>) => {
  server.use(
    http.get(`api/buckets/${bucket}/list`, ({ request }) => {
      const raw = new URL(request.url).searchParams.get('prefix') ?? '';
      const prefix = raw === '/' ? '' : raw;
      const body = prefixMap[prefix] ?? { folders: [], objects: [] };
      return HttpResponse.json(body);
    }),
  );
};

// Allows us to mock API response for the /api/csv_exports?page=... at different
// pages. This enables us to write tests that require navigation between pages
// in our server side-paginated csv_exports table
export const mockServerPaginatedCsvExports = (prefixMap: Record<string, JsonBodyType>) => {
  server.use(
    http.get(`api/csv_exports`, ({ request }) => {
      const raw = new URL(request.url).searchParams.get('page') ?? '';
      const prefix = raw === '/' ? '' : raw;
      const body = prefixMap[prefix] ?? {};
      return HttpResponse.json(body);
    }),
  );
};
