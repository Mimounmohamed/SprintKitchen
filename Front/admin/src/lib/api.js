import axios from 'axios';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:5000/api',
  headers: { 'Content-Type': 'application/json' },
});

// Attach JWT token to every request
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('sk_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Handle 401 — try silent re-login, don't redirect
api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('sk_token');
      // silently re-login
      silentLogin();
    }
    return Promise.reject(err);
  }
);

export async function silentLogin() {
  try {
    const res = await axios.post(
      (import.meta.env.VITE_API_URL || 'http://localhost:5000/api') + '/auth/login',
      { email: 'admin@sprintkitchen.fr', password: 'Admin1234!' }
    );
    const token = res.data?.token || res.data?.data?.token;
    if (token) localStorage.setItem('sk_token', token);
  } catch (e) {
    console.warn('Auto-login failed:', e.message);
  }
}

export default api;
