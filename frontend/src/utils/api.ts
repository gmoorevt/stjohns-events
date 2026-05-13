import axios from 'axios';

export const getApiUrl = (endpoint: string): string => {
  const baseUrl = (import.meta.env.VITE_API_URL || '').replace(/\/$/, '');
  return `${baseUrl}/api${endpoint}`;
};

axios.defaults.withCredentials = true;

let onUnauthorizedHandler: (() => void) | null = null;

export const setUnauthorizedHandler = (handler: () => void) => {
  onUnauthorizedHandler = handler;
};

axios.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err?.response?.status === 401 && onUnauthorizedHandler) {
      onUnauthorizedHandler();
    }
    return Promise.reject(err);
  }
);
