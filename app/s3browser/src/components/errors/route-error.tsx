import { Container } from 'react-bootstrap';
import { useRouteError, isRouteErrorResponse } from 'react-router';

type RouteErrorFallbackProps = {
  errorMessage?: string;
};

export const RouteErrorFallback: React.FC<RouteErrorFallbackProps> = ({ errorMessage }) => {
  const error = useRouteError();

  return (
    <Container className="mt-5 p-0">
      <h3>Oops, something went wrong</h3>
      <br />
      <p>{errorMessage || 'The application encountered an error.'}</p>
      {isRouteErrorResponse(error) && (
        <Container>
          <p>
            {error.status} {error.statusText}
          </p>
          <pre>{JSON.stringify(error.data, null, 2)}</pre>
        </Container>
      )}
    </Container>
  );
};
