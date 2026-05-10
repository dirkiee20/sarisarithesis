'use client';
import { useState, useEffect } from 'react';
import AppShell from '@/components/AppShell';
import api from '@/lib/api';

const TIER_COLORS   = { free: 'badge-gray', pro: 'badge-purple', enterprise: 'badge-green' };
const STATUS_COLORS = { active: 'badge-green', inactive: 'badge-gray', suspended: 'badge-red', cancelled: 'badge-amber' };

function formatDate(d) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-PH', { year: 'numeric', month: 'short', day: 'numeric' });
}

export default function SubscriptionsPage() {
  const [tenants, setTenants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState(null);

  useEffect(() => {
    Promise.all([
      api.getTenants({ limit: 100 }),
      api.getPlatformStats(),
    ])
      .then(([t, s]) => {
        setTenants(t.tenants || []);
        setStats(s.stats || {});
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  const tierBreakdown = [
    { tier: 'free',       label: 'Free',       price: '₱0',        color: 'badge-gray',   count: stats?.free_tenants || 0 },
    { tier: 'pro',        label: 'Pro',         price: '₱299/mo',   color: 'badge-purple', count: stats?.pro_tenants || 0 },
    { tier: 'enterprise', label: 'Enterprise',  price: '₱999/mo',   color: 'badge-green',  count: stats?.enterprise_tenants || 0 },
  ];

  const estimatedMRR =
    (stats?.pro_tenants || 0) * 299 +
    (stats?.enterprise_tenants || 0) * 999;

  return (
    <AppShell title="Subscriptions" subtitle="Manage all store subscriptions and billing tiers">
      {/* MRR & tier summary */}
      <div className="kpi-grid" style={{ marginBottom: 24 }}>
        <div className="kpi-card green">
          <div className="kpi-icon green">💰</div>
          <div className="kpi-value">₱{estimatedMRR.toLocaleString()}</div>
          <div className="kpi-label">Est. Monthly Revenue</div>
          <div className="kpi-change up">↗ From paid tiers</div>
        </div>
        {tierBreakdown.map((t) => (
          <div key={t.tier} className={`kpi-card`}>
            <div className="kpi-icon purple">🏷️</div>
            <div className="kpi-value">{t.count}</div>
            <div className="kpi-label">{t.label} — {t.price}</div>
            <div className="kpi-change neutral">↗ Stores on this tier</div>
          </div>
        ))}
        <div className="kpi-card red">
          <div className="kpi-icon red">⛔</div>
          <div className="kpi-value">{stats?.suspended_tenants || 0}</div>
          <div className="kpi-label">Suspended Accounts</div>
          <div className="kpi-change neutral">Needs review</div>
        </div>
      </div>

      {/* Subscriptions table */}
      <div className="card" style={{ padding: 0 }}>
        <div style={{ padding: '20px 20px 0' }}>
          <div className="card-title">All Store Subscriptions</div>
          <div className="card-subtitle" style={{ marginBottom: 16 }}>
            {tenants.length} total stores
          </div>
        </div>

        <div className="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>Store</th>
                <th>Tier</th>
                <th>Status</th>
                <th>Monthly Value</th>
                <th>Since</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: 48 }}>
                    <div className="spinner" style={{ margin: '0 auto' }} />
                  </td>
                </tr>
              ) : (
                tenants.map((t) => {
                  const price = t.subscription_tier === 'pro' ? 299
                    : t.subscription_tier === 'enterprise' ? 999 : 0;
                  return (
                    <tr key={t.id}>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                          <div className="avatar avatar-sm">{t.business_name?.charAt(0)}</div>
                          <div>
                            <div style={{ fontWeight: 600, fontSize: 13 }}>{t.business_name}</div>
                            <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{t.owner_email}</div>
                          </div>
                        </div>
                      </td>
                      <td><span className={`badge ${TIER_COLORS[t.subscription_tier]}`}>{t.subscription_tier}</span></td>
                      <td><span className={`badge ${STATUS_COLORS[t.subscription_status]}`}>{t.subscription_status}</span></td>
                      <td style={{ fontWeight: 600, color: price > 0 ? 'var(--success)' : 'var(--text-muted)' }}>
                        {price > 0 ? `₱${price}/mo` : 'Free'}
                      </td>
                      <td style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{formatDate(t.created_at)}</td>
                      <td>
                        <TierQuickChange tenant={t} />
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </AppShell>
  );
}

function TierQuickChange({ tenant }) {
  const [tier, setTier] = useState(tenant.subscription_tier);
  const [saving, setSaving] = useState(false);

  const handleChange = async (newTier) => {
    setSaving(true);
    setTier(newTier);
    try {
      await api.updateTenantSubscription(tenant.id, { tier: newTier });
    } catch (err) {
      alert(err.message);
      setTier(tenant.subscription_tier);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div style={{ display: 'flex', gap: 4 }}>
      {['free', 'pro', 'enterprise'].map((t) => (
        <button
          key={t}
          disabled={saving || tier === t}
          onClick={() => handleChange(t)}
          className={`btn btn-xs ${tier === t ? 'btn-primary' : 'btn-ghost'}`}
          style={{ textTransform: 'capitalize' }}
        >
          {saving && tier !== t ? '...' : t}
        </button>
      ))}
    </div>
  );
}
