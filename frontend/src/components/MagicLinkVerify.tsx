import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import axios from 'axios';
import { getApiUrl } from '../utils/api';
import { useAuth } from '../contexts/AuthContext';

export default function MagicLinkVerify() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const { refresh } = useAuth();
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = params.get('token');
    if (!token) {
      setError('Missing token');
      return;
    }
    (async () => {
      try {
        await axios.get(getApiUrl('/auth/magic-link/verify'), { params: { token } });
        await refresh();
        navigate('/', { replace: true });
      } catch (err: any) {
        setError(err?.response?.data?.detail ?? 'Invalid or expired link');
      }
    })();
  }, [params, navigate, refresh]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 p-4">
      <div className="bg-white rounded shadow p-6 max-w-sm w-full text-center">
        {error ? (
          <>
            <p className="text-red-600 font-medium mb-2">{error}</p>
            <button
              onClick={() => navigate('/login')}
              className="text-indigo-600 hover:underline"
            >
              Back to sign in
            </button>
          </>
        ) : (
          <>
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600 mx-auto mb-3" />
            <p className="text-gray-600">Signing you in…</p>
          </>
        )}
      </div>
    </div>
  );
}
