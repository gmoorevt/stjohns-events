import { FormEvent, useState } from 'react';
import axios from 'axios';
import { getApiUrl } from '../utils/api';
import { useAuth } from '../contexts/AuthContext';
import Header from './Header';

export default function Account() {
  const { user } = useAuth();
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(false);
    if (password.length < 8) {
      setError('Password must be at least 8 characters');
      return;
    }
    if (password !== confirm) {
      setError('Passwords do not match');
      return;
    }
    setSubmitting(true);
    try {
      await axios.post(getApiUrl('/auth/set-password'), { password });
      setPassword('');
      setConfirm('');
      setSuccess(true);
    } catch (err: any) {
      setError(err?.response?.data?.detail ?? 'Could not update password');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <Header />
      <main className="max-w-md mx-auto p-6">
        <h1 className="text-2xl font-bold text-gray-900 mb-1">Account</h1>
        <p className="text-gray-500 text-sm mb-6">Signed in as {user?.email}</p>

        <div className="bg-white rounded shadow p-6">
          <h2 className="text-lg font-semibold mb-4">Set or change password</h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">New password</label>
              <input
                type="password"
                required
                minLength={8}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full border border-gray-300 rounded px-3 py-2"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Confirm password</label>
              <input
                type="password"
                required
                minLength={8}
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                className="w-full border border-gray-300 rounded px-3 py-2"
              />
            </div>
            <button
              type="submit"
              disabled={submitting}
              className="w-full bg-indigo-600 text-white rounded py-2 font-medium hover:bg-indigo-700 disabled:opacity-50"
            >
              {submitting ? 'Saving…' : 'Save password'}
            </button>
            {error && <div className="text-red-600 text-sm">{error}</div>}
            {success && <div className="text-green-600 text-sm">Password updated.</div>}
          </form>
        </div>
      </main>
    </div>
  );
}
