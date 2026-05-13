import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

export default function Header() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  if (!user) return null;

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  return (
    <div className="bg-white border-b border-gray-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3 flex items-center justify-between">
        <div className="flex items-center gap-6 text-sm">
          <Link to="/" className="font-semibold text-indigo-700 hover:text-indigo-900">Dashboard</Link>
          {user.role === 'admin' && (
            <>
              <Link to="/admin" className="text-gray-600 hover:text-gray-900">Admin</Link>
              <Link to="/admin/users" className="text-gray-600 hover:text-gray-900">Users</Link>
            </>
          )}
          <Link to="/account" className="text-gray-600 hover:text-gray-900">Account</Link>
        </div>
        <div className="flex items-center gap-3 text-sm">
          <span className="text-gray-500">{user.email}</span>
          {user.role === 'admin' && (
            <span className="bg-indigo-100 text-indigo-700 text-xs font-semibold px-2 py-0.5 rounded">admin</span>
          )}
          <button
            onClick={handleLogout}
            className="text-gray-600 hover:text-gray-900 border border-gray-300 px-3 py-1 rounded hover:bg-gray-50"
          >
            Sign out
          </button>
        </div>
      </div>
    </div>
  );
}
