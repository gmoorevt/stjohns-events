// Utility function to construct API URLs that work in both development and production
export const getApiUrl = (endpoint: string): string => {
  const baseUrl = import.meta.env.VITE_API_URL || '';
  // In development, VITE_API_URL is not set, so we use /api
  // In production, VITE_API_URL is set to /api, so we don't need to add it again
  const apiPrefix = baseUrl === '' ? '/api' : '';
  return `${baseUrl}${apiPrefix}${endpoint}`;
}; 