import { FormEvent, useEffect, useState } from 'react';
import axios from 'axios';
import { getApiUrl } from '../utils/api';
import { useAuth } from '../contexts/AuthContext';
import Header from './Header';

interface ManagedUser {
  id: number;
  email: string;
  role: 'admin' | 'user';
  has_password: boolean;
  created_at: string;
}

export default function AdminUsers() {
  const { user: currentUser } = useAuth();
  const [users, setUsers] = useState<ManagedUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [newEmail, setNewEmail] = useState('');
  const [newRole, setNewRole] = useState<'admin' | 'user'>('user');
  const [creating, setCreating] = useState(false);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await axios.get<ManagedUser[]>(getApiUrl('/admin/users'));
      setUsers(res.data);
    } catch (err: any) {
      setError(err?.response?.data?.detail ?? 'Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const handleCreate = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setCreating(true);
    try {
      await axios.post(getApiUrl('/admin/users'), { email: newEmail, role: newRole });
      setNewEmail('');
      setNewRole('user');
      await load();
    } catch (err: any) {
      setError(err?.response?.data?.detail ?? 'Failed to create user');
    } finally {
      setCreating(false);
    }
  };

  const changeRole = async (id: number, role: 'admin' | 'user') => {
    try {
      await axios.patch(getApiUrl(`/admin/users/${id}`), { role });
      await load();
    } catch (err: any) {
      setError(err?.response?.data?.detail ?? 'Failed to update user');
    }
  };

  const remove = async (id: number, email: string) => {
    if (!window.confirm(`Delete user ${email}?`)) return;
    try {
      await axios.delete(getApiUrl(`/admin/users/${id}`));
      await load();
    } catch (err: any) {
      setError(err?.response?.data?.detail ?? 'Failed to delete user');
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <Header />
      <main className="max-w-4xl mx-auto p-6">
        <h1 className="text-2xl font-bold text-gray-900 mb-6">Users</h1>

        <div className="bg-white rounded shadow p-6 mb-8">
          <h2 className="text-lg font-semibold mb-4">Add user</h2>
          <form onSubmit={handleCreate} className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-end">
            <div className="flex-1">
              <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
              <input
                type="email"
                required
                value={newEmail}
                onChange={(e) => setNewEmail(e.target.value)}
                className="w-full border border-gray-300 rounded px-3 py-2"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
              <select
                value={newRole}
                onChange={(e) => setNewRole(e.target.value as 'admin' | 'user')}
                className="border border-gray-300 rounded px-3 py-2"
              >
                <option value="user">User</option>
                <option value="admin">Admin</option>
              </select>
            </div>
            <button
              type="submit"
              disabled={creating}
              className="bg-indigo-600 text-white rounded px-4 py-2 font-medium hover:bg-indigo-700 disabled:opacity-50"
            >
              {creating ? 'Adding…' : 'Add user'}
            </button>
          </form>
          <p className="text-xs text-gray-500 mt-2">The new user signs in with a magic link to their email. They can set a password from their Account page.</p>
        </div>

        {error && <div className="bg-red-50 text-red-700 px-4 py-2 rounded mb-4">{error}</div>}

        <div className="bg-white rounded shadow overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-2 text-left text-xs font-semibold text-gray-500 uppercase">Email</th>
                <th className="px-4 py-2 text-left text-xs font-semibold text-gray-500 uppercase">Role</th>
                <th className="px-4 py-2 text-left text-xs font-semibold text-gray-500 uppercase">Password set</th>
                <th className="px-4 py-2 text-right text-xs font-semibold text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading ? (
                <tr><td colSpan={4} className="px-4 py-6 text-center text-gray-500">Loading…</td></tr>
              ) : users.length === 0 ? (
                <tr><td colSpan={4} className="px-4 py-6 text-center text-gray-500">No users yet.</td></tr>
              ) : (
                users.map((u) => {
                  const isSelf = u.id === currentUser?.id;
                  return (
                    <tr key={u.id}>
                      <td className="px-4 py-3 text-sm text-gray-900">{u.email}{isSelf && <span className="text-xs text-gray-400 ml-1">(you)</span>}</td>
                      <td className="px-4 py-3 text-sm">
                        <select
                          value={u.role}
                          onChange={(e) => changeRole(u.id, e.target.value as 'admin' | 'user')}
                          disabled={isSelf}
                          className="border border-gray-300 rounded px-2 py-1 text-sm disabled:bg-gray-100"
                        >
                          <option value="user">User</option>
                          <option value="admin">Admin</option>
                        </select>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-500">{u.has_password ? 'yes' : 'no'}</td>
                      <td className="px-4 py-3 text-right">
                        <button
                          onClick={() => remove(u.id, u.email)}
                          disabled={isSelf}
                          className="text-red-600 hover:text-red-800 text-sm disabled:opacity-40 disabled:cursor-not-allowed"
                        >
                          Delete
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </main>
    </div>
  );
}
