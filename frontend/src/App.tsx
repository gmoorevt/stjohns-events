import { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, useNavigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from 'react-query';
import { AuthProvider } from './contexts/AuthContext';
import { setUnauthorizedHandler } from './utils/api';
import Dashboard from './components/Dashboard';
import Admin from './components/Admin';
import AdminUsers from './components/AdminUsers';
import Account from './components/Account';
import Login from './components/Login';
import MagicLinkVerify from './components/MagicLinkVerify';
import RequireAuth from './components/RequireAuth';

const queryClient = new QueryClient();

function UnauthorizedRedirectInstaller() {
  const navigate = useNavigate();
  useEffect(() => {
    setUnauthorizedHandler(() => {
      if (window.location.pathname !== '/login' && !window.location.pathname.startsWith('/auth/')) {
        navigate('/login', { replace: true });
      }
    });
  }, [navigate]);
  return null;
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Router>
        <AuthProvider>
          <UnauthorizedRedirectInstaller />
          <div className="min-h-screen bg-gray-50">
            <Routes>
              <Route path="/login" element={<Login />} />
              <Route path="/auth/verify" element={<MagicLinkVerify />} />
              <Route path="/" element={<RequireAuth><Dashboard /></RequireAuth>} />
              <Route path="/account" element={<RequireAuth><Account /></RequireAuth>} />
              <Route path="/admin" element={<RequireAuth adminOnly><Admin /></RequireAuth>} />
              <Route path="/admin/users" element={<RequireAuth adminOnly><AdminUsers /></RequireAuth>} />
            </Routes>
          </div>
        </AuthProvider>
      </Router>
    </QueryClientProvider>
  );
}

export default App;
