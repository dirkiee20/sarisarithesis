const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';

const getToken = () => {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('admin_token');
};

const request = async (path, options = {}) => {
  const token = getToken();
  const response = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(data.error || `HTTP ${response.status}`);
  }

  return data;
};

export const api = {
  adminLogin: (email, password) =>
    request('/api/admin/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    }),

  getPlatformStats: () => request('/api/admin/platform-stats'),
  getAdminAiOverview: () => request('/api/admin/ai/overview'),

  getTenants: (params = {}) => {
    const qs = new URLSearchParams(params).toString();
    return request(`/api/admin/tenants${qs ? `?${qs}` : ''}`);
  },

  getAllTenants: async (params = {}) => {
    const limit = params.limit || 100;
    const firstPage = await api.getTenants({ ...params, page: 1, limit });
    const tenants = [...(firstPage.tenants || [])];
    const totalPages = firstPage.pagination?.totalPages || 1;

    for (let page = 2; page <= totalPages; page += 1) {
      const nextPage = await api.getTenants({ ...params, page, limit });
      tenants.push(...(nextPage.tenants || []));
    }

    return tenants;
  },

  getTenantById: (id) => request(`/api/admin/tenants/${id}`),
  getTenantAiInsights: (id) => request(`/api/admin/tenants/${id}/ai-insights`),

  getUsers: (params = {}) => {
    const qs = new URLSearchParams(params).toString();
    return request(`/api/admin/users${qs ? `?${qs}` : ''}`);
  },

  updateTenantSubscription: (id, data) =>
    request(`/api/admin/tenants/${id}/subscription`, {
      method: 'PATCH',
      body: JSON.stringify(data),
    }),
};

export default api;
