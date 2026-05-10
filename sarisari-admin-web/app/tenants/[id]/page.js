'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import AppShell from '@/components/AppShell';
import AiForecastPanel from '@/components/AiForecastPanel';
import RestockRecommendationsPanel from '@/components/RestockRecommendationsPanel';
import api from '@/lib/api';

const TIER_COLORS = {
  free: 'badge-gray',
  pro: 'badge-purple',
  enterprise: 'badge-green',
};

const STATUS_COLORS = {
  active: 'badge-green',
  inactive: 'badge-gray',
  suspended: 'badge-red',
  cancelled: 'badge-amber',
};

const ROLE_COLORS = {
  owner: 'badge-purple',
  manager: 'badge-blue',
  staff: 'badge-gray',
  cashier: 'badge-gray',
};

function formatDate(value) {
  if (!value) return '-';
  return new Date(value).toLocaleDateString('en-PH', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

function formatDateTime(value) {
  if (!value) return 'Never';
  return new Date(value).toLocaleString('en-PH', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function formatCurrency(value, options = {}) {
  const { compact = false, decimals = 2 } = options;

  return new Intl.NumberFormat('en-PH', {
    style: 'currency',
    currency: 'PHP',
    notation: compact ? 'compact' : 'standard',
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(Number(value || 0));
}

function formatPercent(value) {
  const prefix = Number(value || 0) > 0 ? '+' : '';
  return `${prefix}${Number(value || 0).toFixed(1)}%`;
}

function getForecastSignalLabel(signal) {
  if (signal === 'growth') return 'Growth expected';
  if (signal === 'softening') return 'Possible slowdown';
  return 'Stable trend';
}

function getForecastSignalBadge(signal) {
  if (signal === 'growth') return 'badge-green';
  if (signal === 'softening') return 'badge-amber';
  return 'badge-blue';
}

export default function TenantDetailPage() {
  const { id } = useParams();
  const router = useRouter();
  const [data, setData] = useState(null);
  const [aiInsights, setAiInsights] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelled = false;

    async function fetchData() {
      setLoading(true);

      try {
        const [tenantData, aiData] = await Promise.all([
          api.getTenantById(id),
          api.getTenantAiInsights(id),
        ]);

        if (cancelled) return;

        setData(tenantData);
        setAiInsights(aiData);
        setError('');
      } catch (err) {
        if (cancelled) return;
        console.error(err);
        setError(err.message || 'Unable to load tenant details.');
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    fetchData();

    return () => {
      cancelled = true;
    };
  }, [id]);

  const handleSubscriptionUpdate = async (updates) => {
    try {
      await api.updateTenantSubscription(id, updates);
      setShowModal(false);

      const refreshed = await api.getTenantById(id);
      setData(refreshed);
    } catch (err) {
      alert(err.message);
    }
  };

  if (loading) {
    return (
      <AppShell title="Tenant Detail" subtitle="Loading store context">
        <div className="loading-spinner">
          <div className="spinner" />
        </div>
      </AppShell>
    );
  }

  if (error) {
    return (
      <AppShell title="Tenant Detail" subtitle="Store intelligence and account data">
        <div className="error-banner">{error}</div>
      </AppShell>
    );
  }

  if (!data) {
    return (
      <AppShell title="Not Found" subtitle="Store intelligence and account data">
        <div className="empty-state">
          <div className="empty-icon">?</div>
          <h3>Tenant not found</h3>
        </div>
      </AppShell>
    );
  }

  const { tenant, users, stats } = data;
  const forecastSummary = aiInsights?.forecast?.summary || {};
  const restockSummary = aiInsights?.restock?.summary || {};

  return (
    <AppShell title={tenant.business_name} subtitle={`Tenant ID: ${tenant.id}`}>
      <button className="btn btn-ghost btn-sm" onClick={() => router.back()} style={{ marginBottom: 20 }}>
        Back to Tenants
      </button>

      <div className="grid-2" style={{ marginBottom: 20 }}>
        <div className="card">
          <div className="card-header">
            <div className="card-title">Store Information</div>
            <button className="btn btn-primary btn-sm" onClick={() => setShowModal(true)}>
              Manage
            </button>
          </div>

          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 16,
              marginBottom: 20,
              padding: 16,
              background: 'var(--bg-elevated)',
              borderRadius: 'var(--radius-sm)',
            }}
          >
            <div className="avatar" style={{ width: 48, height: 48, fontSize: 20 }}>
              {tenant.business_name?.charAt(0)?.toUpperCase()}
            </div>
            <div>
              <h2 style={{ fontSize: 18, fontWeight: 700 }}>{tenant.business_name}</h2>
              <p style={{ fontSize: 13, color: 'var(--text-secondary)' }}>{tenant.owner_email}</p>
              <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
                <span className={`badge ${TIER_COLORS[tenant.subscription_tier] || 'badge-gray'}`}>
                  {tenant.subscription_tier}
                </span>
                <span className={`badge ${STATUS_COLORS[tenant.subscription_status] || 'badge-gray'}`}>
                  {tenant.subscription_status}
                </span>
              </div>
            </div>
          </div>

          <div className="detail-grid">
            {[
              { label: 'Phone', value: tenant.phone || '-' },
              { label: 'Address', value: tenant.address || '-' },
              { label: 'Joined', value: formatDate(tenant.created_at) },
              { label: 'Last Updated', value: formatDate(tenant.updated_at) },
            ].map((item) => (
              <div key={item.label} className="detail-item">
                <label>{item.label}</label>
                <p>{item.value}</p>
              </div>
            ))}
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div className="card-title">Store Statistics</div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            {[
              { label: 'Products', value: stats?.products || 0, icon: 'PR', color: 'blue' },
              { label: 'Transactions', value: Number(stats?.transactions || 0).toLocaleString(), icon: 'TX', color: 'amber' },
              { label: 'Total Revenue', value: formatCurrency(stats?.total_revenue), icon: 'RV', color: 'green' },
              { label: 'Expenses', value: Number(stats?.expenses || 0).toLocaleString(), icon: 'EX', color: 'purple' },
            ].map((item) => (
              <div
                key={item.label}
                style={{
                  padding: 16,
                  background: 'var(--bg-elevated)',
                  borderRadius: 'var(--radius-sm)',
                  border: '1px solid var(--border)',
                }}
              >
                <div className={`kpi-icon ${item.color}`} style={{ width: 32, height: 32, fontSize: 12, marginBottom: 8 }}>
                  {item.icon}
                </div>
                <div style={{ fontSize: 20, fontWeight: 800 }}>{item.value}</div>
                <div style={{ fontSize: 11.5, color: 'var(--text-secondary)', marginTop: 2 }}>{item.label}</div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="grid-main-side" style={{ marginBottom: 20 }}>
        <AiForecastPanel
          forecast={aiInsights?.forecast}
          title="AI Revenue Forecast"
          subtitle="Predicted revenue trend for this store based on recent transaction history"
        />

        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">AI Summary</div>
              <div className="card-subtitle">Forecast and inventory actions for this tenant</div>
            </div>
            {aiInsights?.forecast?.signal && (
              <span className={`badge ${getForecastSignalBadge(aiInsights.forecast.signal)}`}>
                {getForecastSignalLabel(aiInsights.forecast.signal)}
              </span>
            )}
          </div>

          <div className="ai-stat-grid" style={{ marginBottom: 18 }}>
            <div className="analytics-inline-stat">
              <span className="analytics-inline-label">Forecast next 30d</span>
              <strong>{formatCurrency(forecastSummary.predictedRevenue30d, { compact: true })}</strong>
            </div>
            <div className="analytics-inline-stat">
              <span className="analytics-inline-label">Forecast delta</span>
              <strong>{formatPercent(forecastSummary.deltaPercent30d)}</strong>
            </div>
          </div>

          <div style={{ marginBottom: 18 }}>
            <div className="info-row">
              <span className="info-row-label">Model confidence</span>
              <span className="info-row-value">{Math.round((aiInsights?.forecast?.confidence || 0) * 100)}%</span>
            </div>
            <div className="info-row">
              <span className="info-row-label">Urgent restocks</span>
              <span className="info-row-value">{Number(restockSummary.critical || 0) + Number(restockSummary.high || 0)}</span>
            </div>
            <div className="info-row">
              <span className="info-row-label">Planned restocks</span>
              <span className="info-row-value">{Number(restockSummary.plannedRestocks || 0)}</span>
            </div>
            <div className="info-row">
              <span className="info-row-label">Overstock watch</span>
              <span className="info-row-value">{Number(restockSummary.overstockRisk || 0)}</span>
            </div>
          </div>

          <div className="ai-note-panel">
            Recommendations are recalculated from historical sales velocity, stock coverage, and product movement so the admin team can spot stockout or overstock risk quickly.
          </div>
        </div>
      </div>

      <RestockRecommendationsPanel
        restock={aiInsights?.restock}
        title="AI Restocking Recommendations"
        subtitle="Per-product restocking periods and quantities for this store"
      />

      <div className="card" style={{ marginTop: 20 }}>
        <div className="card-header">
          <div>
            <div className="card-title">Staff Members</div>
            <div className="card-subtitle">{users?.length || 0} users on this account</div>
          </div>
        </div>

        <div className="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Status</th>
                <th>Last Login</th>
                <th>Joined</th>
              </tr>
            </thead>
            <tbody>
              {(users || []).map((user) => (
                <tr key={user.id}>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      <div className="avatar avatar-sm">{user.full_name?.charAt(0) || '?'}</div>
                      <span style={{ fontWeight: 600 }}>{user.full_name}</span>
                    </div>
                  </td>
                  <td style={{ color: 'var(--text-secondary)', fontSize: 13 }}>{user.email}</td>
                  <td>
                    <span className={`badge ${ROLE_COLORS[user.role] || 'badge-gray'}`}>{user.role}</span>
                  </td>
                  <td>
                    <span className={`badge ${user.is_active ? 'badge-green' : 'badge-red'}`}>
                      {user.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{formatDateTime(user.last_login_at)}</td>
                  <td style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{formatDate(user.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <SubscriptionModal
          tenant={tenant}
          onClose={() => setShowModal(false)}
          onSave={handleSubscriptionUpdate}
        />
      )}
    </AppShell>
  );
}

function SubscriptionModal({ tenant, onClose, onSave }) {
  const [tier, setTier] = useState(tenant.subscription_tier);
  const [status, setStatus] = useState(tenant.subscription_status);
  const [saving, setSaving] = useState(false);

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(event) => event.stopPropagation()}>
        <div className="modal-header">
          <div className="modal-title">Manage Subscription</div>
          <button className="modal-close" onClick={onClose}>
            x
          </button>
        </div>

        <div className="form-group">
          <label className="form-label">Subscription Tier</label>
          <select className="form-select" value={tier} onChange={(event) => setTier(event.target.value)}>
            <option value="free">Free</option>
            <option value="pro">Pro - PHP 299/month</option>
            <option value="enterprise">Enterprise - PHP 999/month</option>
          </select>
        </div>

        <div className="form-group">
          <label className="form-label">Account Status</label>
          <select className="form-select" value={status} onChange={(event) => setStatus(event.target.value)}>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
            <option value="suspended">Suspended</option>
            <option value="cancelled">Cancelled</option>
          </select>
        </div>

        {status === 'suspended' && (
          <div className="error-banner" style={{ marginBottom: 16, fontSize: 12 }}>
            Suspending this account immediately blocks the store from accessing the platform.
          </div>
        )}

        <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
          <button className="btn btn-ghost" onClick={onClose}>
            Cancel
          </button>
          <button
            className="btn btn-primary"
            disabled={saving}
            onClick={async () => {
              setSaving(true);
              try {
                await onSave({ tier, status });
              } finally {
                setSaving(false);
              }
            }}
          >
            {saving ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </div>
    </div>
  );
}
