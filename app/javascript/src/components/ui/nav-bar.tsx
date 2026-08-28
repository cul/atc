import { Link } from 'react-router';
import { useSessionInfo } from '../hooks/use-session-info';
import { getCsrfParam, getCsrfToken } from '../utils/csrf-utils';

const NavBar = () => {
  const { signOutPath } = useSessionInfo();

  return (
    <nav className="d-flex py-2 px-5 bg-primary bg-opacity-25 justify-content-end gap-3">
      <Link to="/browse/buckets" className="btn btn-light btn-sm">
        S3 File Browser
      </Link>
      <Link to="/csv_exports" className="btn btn-light btn-sm">
        View CSV Exports
      </Link>
      <form action={signOutPath} method="post">
        <input type="hidden" name="_method" value="delete" />
        <input type="hidden" name={getCsrfParam()} value={getCsrfToken()} />
        <button type="submit" className="btn btn-light btn-sm">
          Sign out
        </button>
      </form>
    </nav>
  );
};

export default NavBar;
