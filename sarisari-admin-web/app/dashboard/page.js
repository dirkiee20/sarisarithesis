'use client';
import { useState, useEffect } from 'react';
import AppShell from '@/components/AppShell';
import api from '@/lib/api';
import {
  Chart as ChartJS, CategoryScale, LinearScale, BarElement,
  PointElement, LineElement, ArcElement, Tooltip, Legend, Filler,
} from 'chart.js';
import { Bar, Line, Doughnut } from 'react-chartjs-2';

ChartJS.register(
  CategoryScale, LinearScale, BarElement,
  PointElement, LineElement, ArcElement,
  Tooltip, Legend, Filler
);

const CHART_DEFAULTS = {
  plugins: { legend: { display: false } },
  scales: {
    x: { grid: { color: 'rgba(255,255,255,0.04)' }, ticks: { color: '#475569', font: { size: 11 } } },
    y: { grid: { color: 'rgba(255,255,255,0.04)' }, ticks: { color: '#475569', font: { size: 11 } } },
  },
  maintainAspectRatio: false,
};

export default function DashboardPage() {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.getPlatformStats()
      .then(setStats)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  if (loading) return (
    <AppShell title="Dashboard" subtitle="Platform overview">
      <div className="loading-spinner"><div className="spinner" /></div>
    </AppShell>
  );

  const s = stats?.stats || {};
  const signupTrend = stats?.signupTrend || [];

  const tierData = {
    labels: ['Free', 'Pro', 'Enterprise'],
    datasets: [{
      data: [s.free_tenants || 0, s.pro_tenants || 0, s.enterprise_tenants || 0],
      backgroundColor: ['rgba(99,102,241,0.7)', 'rgba(34,197,94,0.7)', 'rgba(245,158,11,0.7)'],
      borderColor: ['#6366f1', '#22c55e', '#f59e0b'],
      borderWidth: 2,
    }],
  };

  const signupChartData = {
    labels: signupTrend.map((d) => {
      const dt = new Date(d.date);
      return `${dt.getMonth() + 1}/${dt.getDate()}`;
    }),
    datasets: [{
      label: 'New Stores',
      data: signupTrend.map((d) => parseInt(d.count)),
      fill: true,
      borderColor: '#6366f1',
      backgroundColor: 'rgba(99,102,241,0.1)',
      pointBackgroundColor: '#6366f1',
      pointRadius: 4,
      tension: 0.4,
    }],
  };

  const kpis = [
    { label: 'Total Tenants', value: s.total_tenants || 0, icon: '🏪', color: 'purple', change: `+${s.new_tenants_30d || 0} this month` },
    { label: 'Active Stores', value: s.active_tenants || 0, icon: '✅', color: 'green', change: 'Currently active' },
    { label: 'Total Users', value: s.total_users || 0, icon: '👥', color: 'blue', change: 'Across all tenants' },
    { label: 'Total Transactions', value: Number(s.total_transactions || 0).toLocaleString(), icon: '🧾', color: 'amber', change: 'All time' },
    { label: 'Platform Revenue', value: `₱${Number(s.platform_total_revenue || 0).toLocaleString('en-PH', { minimumFractionDigits: 2 })}`, icon: '💰', color: 'green', change: 'Across all stores' },
    { label: 'Suspended Stores', value: s.suspended_tenants || 0, icon: '⛔', color: 'red', change: 'Need attention' },
  ];

  const tierColors = { free: 'badge-gray', pro: 'badge-purple', enterprise: 'badge-green' };

  return (
    <AppShell title="Dashboard" subtitle="Live platform overview — all tenants">
      {/* KPI Cards */}
      <div className="kpi-grid">
        {kpis.map((kpi) => (
          <div key={kpi.label} className={`kpi-card ${kpi.color}`}>
            <div className={`kpi-icon ${kpi.color}`}>{kpi.icon}</div>
            <div className="kpi-value">{kpi.value}</div>
            <div className="kpi-label">{kpi.label}</div>
            <div className="kpi-change neutral">↗ {kpi.change}</div>
          </div>
        ))}
      </div>

      {/* Charts row */}
      <div className="grid-main-side" style={{ marginBottom: 20 }}>
        {/* Signup Trend */}
        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">New Store Signups</div>
              <div className="card-subtitle">Last 30 days</div>
            </div>
            <span className="badge badge-purple">{signupTrend.length} days</span>
          </div>
          <div className="chart-container-lg">
            {signupTrend.length > 0 ? (
              <Line
                data={signupChartData}
                options={{
                  ...CHART_DEFAULTS,
                  plugins: {
                    legend: { display: false },
                    tooltip: { backgroundColor: '#1a1a26', titleColor: '#f1f5f9', bodyColor: '#94a3b8' },
                  },
                }}
              />
            ) : (
              <div className="empty-state">
                <div className="empty-icon">📊</div>
                <h3>No signup data yet</h3>
                <p>Data will appear as stores register</p>
              </div>
            )}
          </div>
        </div>

        {/* Tier Breakdown */}
        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Subscription Tiers</div>
              <div className="card-subtitle">Tenant distribution</div>
            </div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'center', height: 180 }}>
            <Doughnut
              data={tierData}
              options={{
                maintainAspectRatio: false,
                plugins: {
                  legend: {
                    display: true,
                    position: 'bottom',
                    labels: { color: '#94a3b8', font: { size: 12 }, padding: 16 },
                  },
                  tooltip: { backgroundColor: '#1a1a26', titleColor: '#f1f5f9', bodyColor: '#94a3b8' },
                },
                cutout: '65%',
              }}
            />
          </div>

          {/* Tier rows */}
          <div style={{ marginTop: 16 }}>
            {[
              { label: 'Free', count: s.free_tenants || 0, color: 'badge-gray' },
              { label: 'Pro', count: s.pro_tenants || 0, color: 'badge-purple' },
              { label: 'Enterprise', count: s.enterprise_tenants || 0, color: 'badge-green' },
            ].map((tier) => (
              <div key={tier.label} className="info-row">
                <span className="info-row-label">
                  <span className={`badge ${tier.color}`}>{tier.label}</span>
                </span>
                <span className="info-row-value">{tier.count} stores</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Quick platform health */}
      <div className="card">
        <div className="card-header">
          <div className="card-title">Platform Health</div>
          <span className="badge badge-green">● All Systems Operational</span>
        </div>
        <div className="grid-3">
          {[
            { label: 'API Server', status: 'Operational', icon: '🚀', color: 'green' },
            { label: 'Database', status: 'Connected', icon: '🗄️', color: 'green' },
            { label: 'Auth Service', status: 'Active', icon: '🔐', color: 'green' },
          ].map((svc) => (
            <div key={svc.label} style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: 16, background: 'var(--bg-elevated)',
              borderRadius: 'var(--radius-sm)', border: '1px solid var(--border)',
            }}>
              <span style={{ fontSize: 22 }}>{svc.icon}</span>
              <div>
                <div style={{ fontWeight: 600, fontSize: 13 }}>{svc.label}</div>
                <div style={{ fontSize: 12, color: 'var(--success)', marginTop: 2 }}>● {svc.status}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </AppShell>
  );
}
