import { createContext, useCallback, useContext, useEffect, useMemo, useState, ReactNode } from 'react';
import axios from 'axios';
import { getApiUrl } from '../utils/api';

export interface AuthUser {
  id: number;
  email: string;
  role: 'admin' | 'user';
}

interface AuthContextValue {
  user: AuthUser | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  requestMagicLink: (email: string) => Promise<void>;
  logout: () => Promise<void>;
  refresh: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    try {
      const res = await axios.get<AuthUser>(getApiUrl('/auth/me'));
      setUser(res.data);
    } catch {
      setUser(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const login = useCallback(async (email: string, password: string) => {
    const res = await axios.post<AuthUser>(getApiUrl('/auth/login'), { email, password });
    setUser(res.data);
  }, []);

  const requestMagicLink = useCallback(async (email: string) => {
    await axios.post(getApiUrl('/auth/magic-link'), { email });
  }, []);

  const logout = useCallback(async () => {
    try {
      await axios.post(getApiUrl('/auth/logout'));
    } finally {
      setUser(null);
    }
  }, []);

  const value = useMemo(
    () => ({ user, loading, login, requestMagicLink, logout, refresh }),
    [user, loading, login, requestMagicLink, logout, refresh]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
