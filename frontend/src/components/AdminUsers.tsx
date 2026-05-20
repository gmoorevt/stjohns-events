import { FormEvent, useEffect, useState } from 'react';
import axios from 'axios';
import { getApiUrl } from '../utils/api';
import { useAuth } from '../contexts/AuthContext';
import Header from './Header';
import {
  UserPlusIcon,
  ExclamationCircleIcon,
  ClipboardDocumentIcon,
  ClipboardDocumentCheckIcon,
  XMarkIcon,
  BellAlertIcon,
} from '@heroicons/react/24/outline';
import { Card } from './ui/Card';

type UserStatus = 'pending' | 'approved' | 'rejected';

interface ManagedUser {
  id: number;
  email: string;
  role: 'admin' | 'user';
  status: UserStatus;
  has_password: boolean;
  created_at: string;
}

const statusBadgeClass: Record<UserStatus, string> = {
  approved: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  pending: 'bg-amber-50 text-amber-700 border-amber-200',
  rejected: 'bg-slate-100 text-slate-600 border-slate-200',
};

export default function AdminUsers() {
  const { user: currentUser } = useAuth();
  const [users, setUsers] = useState<ManagedUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [newEmail, setNewEmail] = useState('');
  const [newRole, setNewRole] = useState<'admin' | 'user'>('user');
  const [creating, setCreating] = useState(false);

  const [pwModal, setPwModal] = useState<{
    user: ManagedUser;
    customPassword: string;
    generatedPassword: string | null;
    submitting: boolean;
    copied: boolean;
    error: string | null;
  } | null>(null);

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

  const approve = async (id: number) => {
    try {
      await axios.post(getApiUrl(`/admin/users/${id}/approve`));
      await load();
    } catch (err: any) {
      setError(err?.response?.data?.detail ?? 'Failed to approve user');
    }
  };

  const reject = async (id: number, email: string) => {
    if (
      !window.confirm(
        `Reject access for ${email}? They won't be able to request access again unless you delete the rejection.`,
      )
    )
      return;
    try {
      await axios.post(getApiUrl(`/admin/users/${id}/reject`));
      await load();
    } catch (err: any) {
      setError(err?.response?.data?.detail ?? 'Failed to reject user');
    }
  };

  const openSetPassword = (user: ManagedUser) => {
    setPwModal({
      user,
      customPassword: '',
      generatedPassword: null,
      submitting: false,
      copied: false,
      error: null,
    });
  };

  const submitSetPassword = async () => {
    if (!pwModal) return;
    setPwModal({ ...pwModal, submitting: true, error: null });
    try {
      const body = pwModal.customPassword ? { password: pwModal.customPassword } : {};
      const res = await axios.post<{ password: string; user: ManagedUser }>(
        getApiUrl(`/admin/users/${pwModal.user.id}/set-password`),
        body,
      );
      setPwModal({ ...pwModal, submitting: false, generatedPassword: res.data.password });
      await load();
    } catch (err: any) {
      setPwModal({
        ...pwModal,
        submitting: false,
        error: err?.response?.data?.detail ?? 'Failed to set password',
      });
    }
  };

  const copyPassword = async () => {
    if (!pwModal?.generatedPassword) return;
    try {
      await navigator.clipboard.writeText(pwModal.generatedPassword);
      setPwModal({ ...pwModal, copied: true });
    } catch {
      // Clipboard API may be unavailable on insecure contexts
    }
  };

  const pendingUsers = users.filter((u) => u.status === 'pending');
  const decidedUsers = users.filter((u) => u.status !== 'pending');

  const inputClass =
    'w-full border border-slate-300 rounded-md px-3 py-2 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition';

  return (
    <div className="min-h-screen bg-slate-50">
      <Header />
      <main className="max-w-4xl mx-auto px-4 sm:px-6 py-8 space-y-6">
        <h1 className="text-lg font-semibold text-slate-900">Users</h1>

        {/* Add user card */}
        <Card className="p-6">
          <div className="flex items-center gap-2 mb-4">
            <UserPlusIcon className="w-4 h-4 text-slate-400" />
            <h2 className="text-sm font-semibold text-slate-900">Add user</h2>
          </div>
          <form onSubmit={handleCreate} className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-end">
            <div className="flex-1">
              <label className="block text-sm font-medium text-slate-700 mb-1.5">Email</label>
              <input
                type="email"
                required
                value={newEmail}
                onChange={(e) => setNewEmail(e.target.value)}
                placeholder="user@example.com"
                className={inputClass}
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1.5">Role</label>
              <select
                value={newRole}
                onChange={(e) => setNewRole(e.target.value as 'admin' | 'user')}
                className="border border-slate-300 rounded-md px-3 py-2 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition"
              >
                <option value="user">User</option>
                <option value="admin">Admin</option>
              </select>
            </div>
            <button
              type="submit"
              disabled={creating}
              className="bg-indigo-600 text-white rounded-md px-4 py-2 text-sm font-medium hover:bg-indigo-700 disabled:opacity-50 transition-colors whitespace-nowrap"
            >
              {creating ? 'Adding…' : 'Add user'}
            </button>
          </form>
          <p className="text-xs text-slate-400 mt-2">
            The new user signs in with a magic link to their email. They can set a password from their Account page.
          </p>
        </Card>

        {error && (
          <div className="flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-4 py-3">
            <ExclamationCircleIcon className="w-4 h-4 shrink-0 mt-0.5" />
            <span>{error}</span>
          </div>
        )}

        {/* Pending requests */}
        {pendingUsers.length > 0 && (
          <div className="bg-amber-50 border border-amber-200 rounded-lg overflow-hidden">
            <div className="px-4 py-3 border-b border-amber-200 flex items-center gap-2">
              <BellAlertIcon className="w-4 h-4 text-amber-600" />
              <h2 className="text-sm font-semibold text-amber-900">Pending requests</h2>
              <span className="ml-auto inline-flex items-center justify-center w-5 h-5 text-xs font-semibold bg-amber-200 text-amber-900 rounded-full">
                {pendingUsers.length}
              </span>
            </div>
            <ul className="divide-y divide-amber-200">
              {pendingUsers.map((u) => (
                <li
                  key={u.id}
                  className="px-4 py-3 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3"
                >
                  <div>
                    <div className="text-sm font-medium text-slate-900">{u.email}</div>
                    <div className="text-xs text-slate-500">
                      Requested {new Date(u.created_at).toLocaleString()}
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <button
                      onClick={() => approve(u.id)}
                      className="bg-emerald-600 text-white text-xs rounded-md px-3 py-1.5 font-medium hover:bg-emerald-700 transition-colors"
                    >
                      Approve
                    </button>
                    <button
                      onClick={() => openSetPassword(u)}
                      className="bg-indigo-600 text-white text-xs rounded-md px-3 py-1.5 font-medium hover:bg-indigo-700 transition-colors"
                    >
                      Set password
                    </button>
                    <button
                      onClick={() => reject(u.id, u.email)}
                      className="bg-white border border-slate-300 text-slate-700 text-xs rounded-md px-3 py-1.5 font-medium hover:bg-slate-50 transition-colors"
                    >
                      Reject
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Users table */}
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="min-w-full">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50">
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wide">
                    Email
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wide">
                    Role
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wide">
                    Status
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wide">
                    Password
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium text-slate-500 uppercase tracking-wide">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {loading ? (
                  <>
                    {Array.from({ length: 3 }).map((_, i) => (
                      <tr key={i}>
                        <td colSpan={5} className="px-4 py-3">
                          <div className="h-4 bg-slate-100 rounded animate-pulse w-full" />
                        </td>
                      </tr>
                    ))}
                  </>
                ) : decidedUsers.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-sm text-slate-400">
                      No approved users yet.
                    </td>
                  </tr>
                ) : (
                  decidedUsers.map((u) => {
                    const isSelf = u.id === currentUser?.id;
                    return (
                      <tr key={u.id} className="hover:bg-slate-50 transition-colors">
                        <td className="px-4 py-3 text-sm text-slate-900">
                          {u.email}
                          {isSelf && (
                            <span className="ml-1.5 text-xs text-slate-400">(you)</span>
                          )}
                        </td>
                        <td className="px-4 py-3 text-sm">
                          <select
                            value={u.role}
                            onChange={(e) => changeRole(u.id, e.target.value as 'admin' | 'user')}
                            disabled={isSelf}
                            className="border border-slate-300 rounded px-2 py-1 text-xs text-slate-700 disabled:bg-slate-50 disabled:text-slate-400 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                          >
                            <option value="user">User</option>
                            <option value="admin">Admin</option>
                          </select>
                        </td>
                        <td className="px-4 py-3 text-sm">
                          <span
                            className={`inline-flex items-center text-xs font-medium px-2 py-0.5 rounded border ${statusBadgeClass[u.status]}`}
                          >
                            {u.status}
                          </span>
                          {u.status === 'rejected' && !isSelf && (
                            <button
                              onClick={() => approve(u.id)}
                              className="ml-2 text-xs text-indigo-600 hover:text-indigo-800 hover:underline"
                            >
                              Approve anyway
                            </button>
                          )}
                        </td>
                        <td className="px-4 py-3 text-sm text-slate-500">
                          {u.has_password ? 'yes' : 'no'}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <div className="flex justify-end gap-3">
                            <button
                              onClick={() => openSetPassword(u)}
                              className="text-xs text-indigo-600 hover:text-indigo-800 font-medium"
                            >
                              Set password
                            </button>
                            <button
                              onClick={() => remove(u.id, u.email)}
                              disabled={isSelf}
                              className="text-xs text-red-600 hover:text-red-800 font-medium disabled:opacity-40 disabled:cursor-not-allowed"
                            >
                              Delete
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </Card>
      </main>

      {/* Set-password modal */}
      {pwModal && (
        <div
          className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm flex items-center justify-center p-4 z-50"
          onClick={(e) => {
            if (e.target === e.currentTarget) setPwModal(null);
          }}
        >
          <div className="bg-white rounded-lg border border-slate-200 shadow-xl max-w-md w-full p-6">
            <div className="flex items-start justify-between mb-4">
              <h3 className="text-sm font-semibold text-slate-900">
                {pwModal.generatedPassword
                  ? `Password set for ${pwModal.user.email}`
                  : `Set password for ${pwModal.user.email}`}
              </h3>
              <button
                onClick={() => setPwModal(null)}
                className="text-slate-400 hover:text-slate-600 transition-colors -mt-0.5"
                aria-label="Close"
              >
                <XMarkIcon className="w-5 h-5" />
              </button>
            </div>

            {pwModal.generatedPassword ? (
              <>
                <p className="text-xs text-slate-500 mb-3">
                  Copy this now — it won't be shown again. Share it with the user out-of-band
                  (text, Slack, etc.); they can change it from their Account page after signing in.
                </p>
                <div className="flex gap-2 mb-4">
                  <input
                    readOnly
                    value={pwModal.generatedPassword}
                    onFocus={(e) => e.currentTarget.select()}
                    className="flex-1 border border-slate-300 rounded-md px-3 py-2 font-mono text-sm bg-slate-50 text-slate-900 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  />
                  <button
                    onClick={copyPassword}
                    className="inline-flex items-center gap-1.5 bg-indigo-600 text-white rounded-md px-3 py-2 text-sm font-medium hover:bg-indigo-700 transition-colors shrink-0"
                  >
                    {pwModal.copied ? (
                      <ClipboardDocumentCheckIcon className="w-4 h-4" />
                    ) : (
                      <ClipboardDocumentIcon className="w-4 h-4" />
                    )}
                    {pwModal.copied ? 'Copied' : 'Copy'}
                  </button>
                </div>
                <div className="flex justify-end">
                  <button
                    onClick={() => setPwModal(null)}
                    className="bg-slate-100 text-slate-800 rounded-md px-4 py-2 text-sm font-medium hover:bg-slate-200 transition-colors"
                  >
                    Done
                  </button>
                </div>
              </>
            ) : (
              <>
                <p className="text-xs text-slate-500 mb-4">
                  Leave blank to auto-generate a random 12-character password. The user will
                  also be approved if they were pending.
                </p>
                <label className="block text-sm font-medium text-slate-700 mb-1.5">
                  Custom password (optional, min 8 chars)
                </label>
                <input
                  type="text"
                  value={pwModal.customPassword}
                  onChange={(e) => setPwModal({ ...pwModal, customPassword: e.target.value, error: null })}
                  placeholder="(auto-generate)"
                  className="w-full border border-slate-300 rounded-md px-3 py-2 font-mono text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition mb-2"
                />
                {pwModal.error && (
                  <div className="flex items-center gap-2 text-xs text-red-600 mb-3">
                    <ExclamationCircleIcon className="w-4 h-4 shrink-0" />
                    <span>{pwModal.error}</span>
                  </div>
                )}
                <div className="flex justify-end gap-2 mt-4">
                  <button
                    onClick={() => setPwModal(null)}
                    disabled={pwModal.submitting}
                    className="bg-white border border-slate-300 text-slate-700 rounded-md px-4 py-2 text-sm font-medium hover:bg-slate-50 disabled:opacity-50 transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={submitSetPassword}
                    disabled={pwModal.submitting}
                    className="bg-indigo-600 text-white rounded-md px-4 py-2 text-sm font-medium hover:bg-indigo-700 disabled:opacity-50 transition-colors"
                  >
                    {pwModal.submitting ? 'Setting…' : 'Set password'}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
