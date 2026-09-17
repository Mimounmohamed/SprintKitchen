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

// ── Stats / Rapports ──────────────────────────────────────────────────────────
export const statsService = {
  /** One-shot: all data for the Rapports & Statistiques page */
  getSummary:        (params) => api.get('/stats/summary',         { params }),
  /** Rapport Z / Clôture de caisse */
  getRapportZ:       (params) => api.get('/stats/rapport-z',       { params }),
  /** Bar chart: revenue by hour */
  getSalesByHour:    (params) => api.get('/stats/sales-by-hour',   { params }),
  /** Top articles most sold */
  getTopProducts:    (params) => api.get('/stats/top-products',    { params }),
  /** Revenue by channel (sur_place / a_emporter / livraison) */
  getByChannel:      (params) => api.get('/stats/by-channel',      { params }),
  /** Day-by-day revenue trend */
  getSalesTrend:     (params) => api.get('/stats/sales-trend',     { params }),
  /** KPI cards with % vs previous period */
  getKpis:           (params) => api.get('/stats/kpis',            { params }),
  /** Payment method breakdown */
  getPaymentMethods: (params) => api.get('/stats/payment-methods', { params }),
};

// ── Ingredients (Inventaire / Liste 86) ───────────────────────────────────────
export const ingredientService = {
  getAll:          (params)            => api.get('/ingredients',                  { params }),
  getFamilies:     (params)            => api.get('/ingredients/families',         { params }),
  getById:         (id)                => api.get(`/ingredients/${id}`),
  create:          (data)              => api.post('/ingredients',                 data),
  update:          (id, data)          => api.put(`/ingredients/${id}`,            data),
  setAvailability: (id, avail, notes)  => api.patch(`/ingredients/${id}/availability`, { availability: avail, notes }),
  bulkAvailability:(family, avail)     => api.post('/ingredients/bulk-availability',   { family, availability: avail }),
  delete:          (id)                => api.delete(`/ingredients/${id}`),
};

// ── Ingredient Families ───────────────────────────────────────────────────────
export const ingredientFamilyService = {
  getAll:  ()         => api.get('/ingredient-families'),
  create:  (data)     => api.post('/ingredient-families',      data),
  update:  (id, data) => api.put(`/ingredient-families/${id}`, data),
  delete:  (id)       => api.delete(`/ingredient-families/${id}`),
};

// ── Dashboard KPIs ────────────────────────────────────────────────────────────
export const dashboardService = {
  /** Returns { revenue, tickets, rupture } — all live from DB */
  getKpis: () => api.get('/dashboard'),
};
