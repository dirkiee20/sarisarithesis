'use client';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import AppShell from '@/components/AppShell';
import api from '@/lib/api';

const TIER_COLORS = { free: 'badge-gray', pro: 'badge-purple', enterprise: 'badge-green' };
const STATUS_COLORS = { active: 'badge-green', inactive: 'badge-gray', suspended: 'badge-red', cancelled: 'badge-amber' };

function formatDate(d) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-PH', { year: 'numeric', month: 'short', day: 'numeric' });
}

function formatCurrency(v) {
  return `₱${Number(v || 0).toLocaleString('en-PH', { minimumFractionDigits: 2 })}`;
}

export default function TenantsPage() {
  const router = useRouter();
  const [tenants, setTenants] = useState([]);
  const [pagination, setPagination] = useState({});
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [tierFilter, setTierFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [page, setPage] = useState(1);
  const [modal, setModal] = useState(null); // { tenant }

  const fetchTenants = async () => {
    setLoading(true);
    try {
      const params = { page, limit: 15 };
      if (search) params.search = search;
      if (tierFilter) params.tier = tierFilter;
      if (statusFilter) params.status = statusFilter;
      const data = await api.getTenants(params);
      setTenants(data.tenants || []);
      setPagination(data.pagination || {});
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchTenants(); }, [page, tierFilter, statusFilter]);

  // Debounce search
  useEffect(() => {
    const t = setTimeout(() => { setPage(1); fetchTenants(); }, 400);
    return () => clearTimeout(t);
  }, [search]);

  const handleSubscriptionUpdate = async (tenantId, updates) => {
    try {
      await api.updateTenantSubscription(tenantId, updates);
      setModal(null);
      fetchTenants();
    } catch (err) {
      alert(err.message);
    }
  };

  return (
    <AppShell title="Tenants" subtitle="All registered stores on the platform">
      {/* Header */}
      <div className="page-header">
        <div className="page-header-left">
          <h1>All Tenants</h1>
          <p>{pagination.total || 0} stores registered on the platform</p>
        </div>
      </div>

      {/* Filters */}
      <div className="card" style={{ padding: '16px 20px', marginBottom: 20 }}>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'center' }}>
          {/* Search */}
          <div className="search-bar" style={{ flex: 1, minWidth: 200 }}>
            <span className="search-icon">🔍</span>
            <input
              type="text"
              placeholder="Search by store name or email..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{ width: '100%' }}
            />
          </div>

          {/* Tier filter */}
          <select
            className="form-select"
            value={tierFilter}
            onChange={(e) => { setTierFilter(e.target.value); setPage(1); }}
            style={{ width: 140 }}
          >
            <option value="">All Tiers</option>
            <option value="free">Free</option>
            <option value="pro">Pro</option>
            <option value="enterprise">Enterprise</option>
          </select>

          {/* Status filter */}
          <select
            className="form-select"
            value={statusFilter}
            onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }}
            style={{ width: 150 }}
          >
            <option value="">All Statuses</option>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
            <option value="suspended">Suspended</option>
            <option value="cancelled">Cancelled</option>
          </select>
        </div>
      </div>

      {/* Table */}
      <div className="card" style={{ padding: 0 }}>
        <div className="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>Store Name</th>
                <th>Owner Email</th>
                <th>Tier</th>
                <th>Status</th>
                <th>Products</th>
                <th>Transactions</th>
                <th>Revenue</th>
                <th>Joined</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={9} style={{ textAlign: 'center', padding: 48 }}>
                    <div className="spinner" style={{ margin: '0 auto' }} />
                  </td>
                </tr>
              ) : tenants.length === 0 ? (
                <tr>
                  <td colSpan={9}>
                    <div className="empty-state">
                      <div className="empty-icon">🏪</div>
                      <h3>No tenants found</h3>
                      <p>Try adjusting your search or filters</p>
                    </div>
                  </td>
                </tr>
              ) : (
                tenants.map((t) => (
                  <tr key={t.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <div className="avatar avatar-sm">
                          {t.business_name?.charAt(0)?.toUpperCase()}
                        </div>
                        <div>
                          <div style={{ fontWeight: 600 }}>{t.business_name}</div>
                          <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                            {t.user_count} user{t.user_count !== 1 ? 's' : ''}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td style={{ color: 'var(--text-secondary)', fontSize: 13 }}>{t.owner_email}</td>
                    <td>
                      <span className={`badge ${TIER_COLORS[t.subscription_tier] || 'badge-gray'}`}>
                        {t.subscription_tier}
                      </span>
                    </td>
                    <td>
                      <span className={`badge ${STATUS_COLORS[t.subscription_status] || 'badge-gray'}`}>
                        {t.subscription_status}
                      </span>
                    </td>
                    <td>{t.product_count || 0}</td>
                    <td>{Number(t.transaction_count || 0).toLocaleString()}</td>
                    <td style={{ fontWeight: 600 }}>{formatCurrency(t.total_revenue)}</td>
                    <td style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{formatDate(t.created_at)}</td>
                    <td>
                      <div style={{ display: 'flex', gap: 6 }}>
                        <button
                          className="btn btn-ghost btn-xs"
                          onClick={() => router.push(`/tenants/${t.id}`)}
                        >
                          View
                        </button>
                        <button
                          className="btn btn-xs"
                          style={{ background: 'var(--accent-dim)', color: 'var(--accent-light)' }}
                          onClick={() => setModal(t)}
                        >
                          Manage
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {pagination.totalPages > 1 && (
          <div style={{ padding: '0 16px 16px' }}>
            <div className="pagination">
              <span className="pagination-info">
                Showing {((page - 1) * 15) + 1}–{Math.min(page * 15, pagination.total)} of {pagination.total}
              </span>
              <div className="pagination-controls">
                <button className="page-btn" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page === 1}>‹</button>
                {Array.from({ length: pagination.totalPages }, (_, i) => i + 1).map((p) => (
                  <button key={p} className={`page-btn ${p === page ? 'active' : ''}`} onClick={() => setPage(p)}>{p}</button>
                ))}
                <button className="page-btn" onClick={() => setPage((p) => Math.min(pagination.totalPages, p + 1))} disabled={page === pagination.totalPages}>›</button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Manage Subscription Modal */}
      {modal && (
        <SubscriptionModal
          tenant={modal}
          onClose={() => setModal(null)}
          onSave={(updates) => handleSubscriptionUpdate(modal.id, updates)}
        />
      )}
    </AppShell>
  );
}

function SubscriptionModal({ tenant, onClose, onSave }) {
  const [tier, setTier] = useState(tenant.subscription_tier);
  const [status, setStatus] = useState(tenant.subscription_status);
  const [saving, setSaving] = useState(false);

  const handleSave = async () => {
    setSaving(true);
    try { await onSave({ tier, status }); }
    finally { setSaving(false); }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div className="modal-title">Manage Subscription</div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 24,
          padding: '14px 16px', background: 'var(--bg-elevated)', borderRadius: 'var(--radius-sm)' }}>
          <div className="avatar">{tenant.business_name?.charAt(0)?.toUpperCase()}</div>
          <div>
            <div style={{ fontWeight: 700, fontSize: 14 }}>{tenant.business_name}</div>
            <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{tenant.owner_email}</div>
          </div>
        </div>

        <div className="form-group">
          <label className="form-label">Subscription Tier</label>
          <select className="form-select" value={tier} onChange={(e) => setTier(e.target.value)}>
            <option value="free">Free</option>
            <option value="pro">Pro — ₱299/month</option>
            <option value="enterprise">Enterprise — ₱999/month</option>
          </select>
        </div>

        <div className="form-group">
          <label className="form-label">Account Status</label>
          <select className="form-select" value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
            <option value="suspended">Suspended</option>
            <option value="cancelled">Cancelled</option>
          </select>
        </div>

        {status === 'suspended' && (
          <div className="error-banner" style={{ fontSize: 12, marginBottom: 16 }}>
            ⚠️ Suspending will block all store access immediately.
          </div>
        )}

        <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
            {saving ? 'Saving...' : '💾 Save Changes'}
          </button>
        </div>
      </div>
    </div>
  );
}
