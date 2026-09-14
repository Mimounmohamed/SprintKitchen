import api from '../lib/api';

// ── Auth ──────────────────────────────────────────────────────────────────────
export const authService = {
  login: (email, password) => api.post('/auth/login', { email, password }),
  getMe: () => api.get('/auth/me'),
};

// ── Orders ────────────────────────────────────────────────────────────────────
export const orderService = {
  getAll: (params) => api.get('/orders', { params }),
  getById: (id) => api.get(`/orders/${id}`),
  create: (data) => api.post('/orders', data),
  updateStatus: (id, status, extra = {}) =>
    api.patch(`/orders/${id}/status`, { status, ...extra }),
  cancel: (id, reason) => api.patch(`/orders/${id}/cancel`, { reason }),
  getDailyStats: (params) => api.get('/orders/stats/daily', { params }),
};

// ── Products ──────────────────────────────────────────────────────────────────
export const productService = {
  getAll: (params) => api.get('/products', { params }),
  getById: (id) => api.get(`/products/${id}`),
  create: (data) => api.post('/products', data),
  update: (id, data) => api.put(`/products/${id}`, data),
  setAvailability: (id, availability, notes) =>
    api.patch(`/products/${id}/availability`, { availability, notes }),
  bulkAvailability: (categoryId, availability) =>
    api.patch('/products/bulk-availability', { categoryId, availability }),
  delete: (id) => api.delete(`/products/${id}`),
};

// ── Categories ────────────────────────────────────────────────────────────────
export const categoryService = {
  getAll: (params) => api.get('/categories', { params }),
  create: (data) => api.post('/categories', data),
  update: (id, data) => api.put(`/categories/${id}`, data),
  delete: (id) => api.delete(`/categories/${id}`),
};

// ── Customers ─────────────────────────────────────────────────────────────────
export const customerService = {
  search: (params) => api.get('/customers/search', { params }),
  getById: (id) => api.get(`/customers/${id}`),
  create: (data) => api.post('/customers', data),
  update: (id, data) => api.put(`/customers/${id}`, data),
};

// ── Payments ──────────────────────────────────────────────────────────────────
export const paymentService = {
  create: (data) => api.post('/payments', data),
  getByOrder: (orderId) => api.get(`/payments/order/${orderId}`),
  refund: (id, reason) => api.patch(`/payments/${id}/refund`, { reason }),
};

// ── Stock ─────────────────────────────────────────────────────────────────────
export const stockService = {
  getOverview: (params) => api.get('/stock/overview', { params }),
  getLogs: (params) => api.get('/stock/logs', { params }),
};

// ── Registers ─────────────────────────────────────────────────────────────────
export const registerService = {
  getAll: (params) => api.get('/registers', { params }),
  openSession: (id, data) => api.patch(`/registers/${id}/open`, data),
  closeSession: (id, data) => api.patch(`/registers/${id}/close`, data),
};

// ── Stores ────────────────────────────────────────────────────────────────────
export const storeService = {
  getAll: () => api.get('/stores'),
  getById: (id) => api.get(`/stores/${id}`),
};
