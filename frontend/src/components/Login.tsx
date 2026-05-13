import { FormEvent, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

type Tab = 'magic' | 'password';

export default function Login() {
  const { login, requestMagicLink } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const from = (location.state as { from?: string } | null)?.from ?? '/';

  const [tab, setTab] = useState<Tab>('magic');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [magicSent, setMagicSent] = useState(false);

  const handlePasswordSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await login(email, password);
      navigate(from, { replace: true });
    } catch (err: any) {
      setError(err?.response?.data?.detail ?? 'Sign-in failed');
    } finally {
      setSubmitting(false);
    }
  };

  const handleMagicSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await requestMagicLink(email);
      setMagicSent(true);
    } catch (err: any) {
      setError(err?.response?.data?.detail ?? 'Could not send sign-in link');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-indigo-50 via-white to-pink-50 p-4">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md p-8">
        <h1 className="text-2xl font-bold text-indigo-800 mb-1">Summerfest</h1>
        <p className="text-gray-500 mb-6 text-sm">Sign in to continue</p>

        <div className="flex border-b border-gray-200 mb-6">
          <button
            type="button"
            className={`flex-1 py-2 text-sm font-medium ${tab === 'magic' ? 'text-indigo-700 border-b-2 border-indigo-600' : 'text-gray-500'}`}
            onClick={() => { setTab('magic'); setError(null); setMagicSent(false); }}
          >
            Email link
          </button>
          <button
            type="button"
            className={`flex-1 py-2 text-sm font-medium ${tab === 'password' ? 'text-indigo-700 border-b-2 border-indigo-600' : 'text-gray-500'}`}
            onClick={() => { setTab('password'); setError(null); setMagicSent(false); }}
          >
            Password
          </button>
        </div>

        {tab === 'magic' ? (
          magicSent ? (
            <div className="text-center py-6">
              <p className="text-gray-700">If an account exists for <span className="font-semibold">{email}</span>, a sign-in link is on its way.</p>
              <p className="text-xs text-gray-500 mt-2">The link expires in 15 minutes.</p>
            </div>
          ) : (
            <form onSubmit={handleMagicSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
                <input
                  type="email"
                  required
                  autoFocus
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full border border-gray-300 rounded px-3 py-2"
                />
              </div>
              <button
                type="submit"
                disabled={submitting}
                className="w-full bg-indigo-600 text-white rounded py-2 font-medium hover:bg-indigo-700 disabled:opacity-50"
              >
                {submitting ? 'Sending…' : 'Email me a sign-in link'}
              </button>
            </form>
          )
        ) : (
          <form onSubmit={handlePasswordSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
              <input
                type="email"
                required
                autoFocus
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full border border-gray-300 rounded px-3 py-2"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full border border-gray-300 rounded px-3 py-2"
              />
            </div>
            <button
              type="submit"
              disabled={submitting}
              className="w-full bg-indigo-600 text-white rounded py-2 font-medium hover:bg-indigo-700 disabled:opacity-50"
            >
              {submitting ? 'Signing in…' : 'Sign in'}
            </button>
          </form>
        )}

        {error && <div className="mt-4 text-red-600 text-sm">{error}</div>}
      </div>
    </div>
  );
}
