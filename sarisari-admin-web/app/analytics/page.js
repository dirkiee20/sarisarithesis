'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import AiForecastPanel from '@/components/AiForecastPanel';
import RestockRecommendationsPanel from '@/components/RestockRecommendationsPanel';
import api from '@/lib/api';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  ArcElement,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js';
import { Bar, Line, Doughnut } from 'react-chartjs-2';

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  ArcElement,
  Tooltip,
  Legend,
  Filler
);

const CHART_DEFAULTS = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: '#1a1a26',
      titleColor: '#f1f5f9',
      bodyColor: '#94a3b8',
      borderColor: 'rgba(255,255,255,0.08)',
      borderWidth: 1,
    },
  },
  scales: {
    x: {
      grid: { color: 'rgba(255,255,255,0.04)' },
      ticks: { color: '#475569', font: { size: 11 } },
    },
    y: {
      grid: { color: 'rgba(255,255,255,0.04)' },
      ticks: { color: '#475569', font: { size: 11 } },
      beginAtZero: true,
    },
  },
};

const TIER_ORDER = ['free', 'pro', 'enterprise'];
const STATUS_ORDER = ['active', 'inactive', 'suspended', 'cancelled'];
const TIER_LABELS = { free: 'Free', pro: 'Pro', enterprise: 'Enterprise' };
const STATUS_LABELS = {
  active: 'Active',
  inactive: 'Inactive',
  suspended: 'Suspended',
  cancelled: 'Cancelled',
};
const TIER_BADGES = {
  free: 'badge-gray',
  pro: 'badge-purple',
  enterprise: 'badge-green',
};
const STATUS_BADGES = {
  active: 'badge-green',
  inactive: 'badge-gray',
  suspended: 'badge-red',
  cancelled: 'badge-amber',
};
const PLAN_PRICING = { free: 0, pro: 299, enterprise: 999 };

function formatCurrency(value, options = {}) {
  const { compact = false, decimals = 0 } = options;

  return new Intl.NumberFormat('en-PH', {
    style: 'currency',
    currency: 'PHP',
    notation: compact ? 'compact' : 'standard',
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(Number(value || 0));
}

function formatDate(value) {
  if (!value) return 'No date';
  return new Date(value).toLocaleDateString('en-PH', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

function formatPercent(value) {
  return `${Number(value || 0).toFixed(1)}%`;
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

function safeDivide(numerator, denominator) {
  if (!denominator) return 0;
  return numerator / denominator;
}

function startOfDay(date) {
  const next = new Date(date);
  next.setHours(0, 0, 0, 0);
  return next;
}

function getDailySignupSeries(signupTrend, days = 30) {
  const today = startOfDay(new Date());
  const countsByDay = new Map(
    signupTrend.map((entry) => [
      startOfDay(new Date(entry.date)).toISOString().slice(0, 10),
      Number(entry.count || 0),
    ])
  );

  const labels = [];
  const data = [];

  for (let offset = days - 1; offset >= 0; offset -= 1) {
    const cursor = startOfDay(new Date(today));
    cursor.setDate(today.getDate() - offset);
    const key = cursor.toISOString().slice(0, 10);
    labels.push(`${cursor.getMonth() + 1}/${cursor.getDate()}`);
    data.push(countsByDay.get(key) || 0);
  }

  return { labels, data };
}

function getMonthlySignupSeries(tenants, months = 6) {
  const now = new Date();
  const counts = new Map();

  tenants.forEach((tenant) => {
    const createdAt = new Date(tenant.created_at);
    const key = `${createdAt.getFullYear()}-${String(createdAt.getMonth() + 1).padStart(2, '0')}`;
    counts.set(key, (counts.get(key) || 0) + 1);
  });

  const labels = [];
  const data = [];

  for (let offset = months - 1; offset >= 0; offset -= 1) {
    const cursor = new Date(now.getFullYear(), now.getMonth() - offset, 1);
    const key = `${cursor.getFullYear()}-${String(cursor.getMonth() + 1).padStart(2, '0')}`;
    labels.push(
      cursor.toLocaleDateString('en-PH', {
        month: 'short',
        year: offset === months - 1 || cursor.getMonth() === 0 ? 'numeric' : undefined,
      })
    );
    data.push(counts.get(key) || 0);
  }

  return { labels, data };
}

function getTierRevenueBreakdown(tenants) {
  return TIER_ORDER.map((tier) =>
    tenants
      .filter((tenant) => tenant.subscription_tier === tier)
      .reduce((sum, tenant) => sum + Number(tenant.total_revenue || 0), 0)
  );
}

function getStatusCounts(tenants) {
  return STATUS_ORDER.map((status) =>
    tenants.filter((tenant) => tenant.subscription_status === status).length
  );
}

function getTopStores(tenants, count = 5) {
  return [...tenants]
    .sort((left, right) => {
      const revenueDelta = Number(right.total_revenue || 0) - Number(left.total_revenue || 0);
      if (revenueDelta !== 0) return revenueDelta;
      return Number(right.transaction_count || 0) - Number(left.transaction_count || 0);
    })
    .slice(0, count);
}

export default function AnalyticsPage() {
  const [stats, setStats] = useState(null);
  const [tenants, setTenants] = useState([]);
  const [aiOverview, setAiOverview] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelled = false;

    async function loadAnalytics() {
      try {
        const [platformData, allTenants, aiData] = await Promise.all([
          api.getPlatformStats(),
          api.getAllTenants({ limit: 100 }),
          api.getAdminAiOverview(),
        ]);

        if (cancelled) return;

        setStats(platformData);
        setTenants(allTenants);
        setAiOverview(aiData);
        setError('');
      } catch (err) {
        if (cancelled) return;
        console.error(err);
        setError(err.message || 'Unable to load analytics data.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    loadAnalytics();

    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) {
    return (
      <AppShell title="Analytics" subtitle="Growth, revenue, and tenant performance">
        <div className="loading-spinner">
          <div className="spinner" />
        </div>
      </AppShell>
    );
  }

  if (error) {
    return (
      <AppShell title="Analytics" subtitle="Growth, revenue, and tenant performance">
        <div className="error-banner">{error}</div>
      </AppShell>
    );
  }

  const summary = stats?.stats || {};
  const signupTrend = stats?.signupTrend || [];
  const dailySeries = getDailySignupSeries(signupTrend);
  const monthlySeries = getMonthlySignupSeries(tenants, 6);
  const tierRevenue = getTierRevenueBreakdown(tenants);
  const statusCounts = getStatusCounts(tenants);
  const topStores = getTopStores(tenants);

  const paidTenants = Number(summary.pro_tenants || 0) + Number(summary.enterprise_tenants || 0);
  const totalTenants = Number(summary.total_tenants || 0);
  const activeTenants = Number(summary.active_tenants || 0);
  const totalRevenue = Number(summary.platform_total_revenue || 0);
  const totalTransactions = Number(summary.total_transactions || 0);
  const estimatedMrr =
    Number(summary.pro_tenants || 0) * PLAN_PRICING.pro +
    Number(summary.enterprise_tenants || 0) * PLAN_PRICING.enterprise;

  const activeRate = safeDivide(activeTenants * 100, totalTenants);
  const paidConversion = safeDivide(paidTenants * 100, totalTenants);
  const averageRevenuePerTenant = safeDivide(totalRevenue, totalTenants);
  const averageTransactionsPerTenant = safeDivide(totalTransactions, totalTenants);
  const attentionStores =
    tenants.filter((tenant) => ['inactive', 'suspended'].includes(tenant.subscription_status)).length;

  const strongestTier = TIER_ORDER.reduce((best, tier) => {
    const count =
      tier === 'free'
        ? Number(summary.free_tenants || 0)
        : tier === 'pro'
          ? Number(summary.pro_tenants || 0)
          : Number(summary.enterprise_tenants || 0);

    if (!best || count > best.count) {
      return { tier, count };
    }

    return best;
  }, null);

  const strongestDay = dailySeries.data.reduce(
    (best, count, index) => (count > best.count ? { count, label: dailySeries.labels[index] } : best),
    { count: 0, label: 'No activity yet' }
  );
  const forecastSummary = aiOverview?.forecast?.summary || {};
  const restockSummary = aiOverview?.restock?.summary || {};
  const tenantSignals = aiOverview?.tenantSignals || [];

  const signupChartData = {
    labels: dailySeries.labels,
    datasets: [
      {
        label: 'Signups',
        data: dailySeries.data,
        fill: true,
        borderColor: '#6366f1',
        backgroundColor: 'rgba(99,102,241,0.12)',
        pointBackgroundColor: '#818cf8',
        pointRadius: 3,
        tension: 0.35,
      },
    ],
  };

  const monthlyAcquisitionData = {
    labels: monthlySeries.labels,
    datasets: [
      {
        label: 'New tenants',
        data: monthlySeries.data,
        borderRadius: 8,
        backgroundColor: 'rgba(56,189,248,0.65)',
        borderColor: '#38bdf8',
        borderWidth: 1,
      },
    ],
  };

  const tierRevenueData = {
    labels: TIER_ORDER.map((tier) => TIER_LABELS[tier]),
    datasets: [
      {
        label: 'Revenue',
        data: tierRevenue,
        borderRadius: 10,
        backgroundColor: ['rgba(148,163,184,0.55)', 'rgba(99,102,241,0.7)', 'rgba(34,197,94,0.7)'],
        borderColor: ['#94a3b8', '#6366f1', '#22c55e'],
        borderWidth: 1,
      },
    ],
  };

  const statusMixData = {
    labels: STATUS_ORDER.map((status) => STATUS_LABELS[status]),
    datasets: [
      {
        data: statusCounts,
        backgroundColor: ['rgba(34,197,94,0.7)', 'rgba(148,163,184,0.7)', 'rgba(239,68,68,0.7)', 'rgba(245,158,11,0.7)'],
        borderColor: ['#22c55e', '#94a3b8', '#ef4444', '#f59e0b'],
        borderWidth: 2,
      },
    ],
  };

  const insightCards = [
    {
      title: 'Top earning tenant',
      value: topStores[0]?.business_name || 'No tenant data yet',
      meta: topStores[0] ? formatCurrency(topStores[0].total_revenue, { compact: true }) : 'Waiting for revenue data',
    },
    {
      title: 'Best signup day',
      value: strongestDay.label,
      meta: strongestDay.count > 0 ? `${strongestDay.count} new tenants` : 'No signups in the current window',
    },
    {
      title: 'Largest segment',
      value: strongestTier ? TIER_LABELS[strongestTier.tier] : 'No tenants yet',
      meta: strongestTier ? `${strongestTier.count} stores on this plan` : 'No segment data',
    },
    {
      title: 'Attention required',
      value: `${attentionStores}`,
      meta: attentionStores > 0 ? 'Inactive or suspended stores to review' : 'No stores need immediate review',
    },
  ];

  const aiInsightCards = [
    {
      title: 'AI forecast next 30 days',
      value: aiOverview ? formatCurrency(forecastSummary.predictedRevenue30d, { compact: true }) : 'No forecast',
      meta: aiOverview
        ? `${formatPercent(forecastSummary.deltaPercent30d)} versus the last 30 days`
        : 'Need transaction history to project revenue',
    },
    {
      title: 'Forecast signal',
      value: aiOverview ? getForecastSignalLabel(aiOverview?.forecast?.signal) : 'Not available',
      meta: aiOverview
        ? `${Math.round((aiOverview?.forecast?.confidence || 0) * 100)}% model confidence`
        : 'Confidence appears after the first forecast run',
    },
    {
      title: 'Urgent restocks',
      value: `${Number(restockSummary.critical || 0) + Number(restockSummary.high || 0)}`,
      meta: aiOverview
        ? `${Number(restockSummary.stockoutRisk || 0)} products are close to stocking out`
        : 'Inventory movement data required',
    },
    {
      title: 'Overstock watch',
      value: `${Number(restockSummary.overstockRisk || 0)}`,
      meta: aiOverview
        ? `${Number(restockSummary.actionable || 0)} total product actions generated`
        : 'No inventory recommendation data yet',
    },
  ];

  return (
    <AppShell title="Analytics" subtitle="Growth, revenue, and tenant performance">
      <div className="page-header">
        <div className="page-header-left">
          <h1>Platform Analytics</h1>
          <p>Cross-tenant trends, conversion, and store performance in one view.</p>
        </div>
        <div className="analytics-chip-row">
          <span className="badge badge-purple">{totalTenants} tracked stores</span>
          <span className="badge badge-blue">{signupTrend.length} daily signup points</span>
          <span className="badge badge-green">Updated from live admin data</span>
        </div>
      </div>

      <div className="kpi-grid">
        <div className="kpi-card green">
          <div className="kpi-icon green">RV</div>
          <div className="kpi-value">{formatCurrency(totalRevenue, { compact: true })}</div>
          <div className="kpi-label">Platform revenue</div>
          <div className="kpi-change neutral">{formatCurrency(averageRevenuePerTenant)} average per store</div>
        </div>

        <div className="kpi-card">
          <div className="kpi-icon purple">MR</div>
          <div className="kpi-value">{formatCurrency(estimatedMrr)}</div>
          <div className="kpi-label">Estimated MRR</div>
          <div className="kpi-change neutral">{paidTenants} paid tenants across the platform</div>
        </div>

        <div className="kpi-card blue">
          <div className="kpi-icon blue">CV</div>
          <div className="kpi-value">{formatPercent(paidConversion)}</div>
          <div className="kpi-label">Paid conversion</div>
          <div className="kpi-change neutral">Pro and enterprise share of total tenants</div>
        </div>

        <div className="kpi-card">
          <div className="kpi-icon purple">AC</div>
          <div className="kpi-value">{formatPercent(activeRate)}</div>
          <div className="kpi-label">Activation rate</div>
          <div className="kpi-change neutral">{activeTenants} stores currently active</div>
        </div>

        <div className="kpi-card amber">
          <div className="kpi-icon amber">TX</div>
          <div className="kpi-value">{averageTransactionsPerTenant.toFixed(1)}</div>
          <div className="kpi-label">Avg. transactions per store</div>
          <div className="kpi-change neutral">{Number(summary.total_transactions || 0).toLocaleString()} total transactions</div>
        </div>
      </div>

      <div className="analytics-insights-grid">
        {aiInsightCards.map((card) => (
          <div key={card.title} className="analytics-insight-card">
            <div className="analytics-insight-label">{card.title}</div>
            <div className="analytics-insight-value">{card.value}</div>
            <div className="analytics-insight-meta">{card.meta}</div>
          </div>
        ))}
      </div>

      <div className="grid-main-side" style={{ marginBottom: 20 }}>
        <AiForecastPanel
          forecast={aiOverview?.forecast}
          title="AI Sales Forecast"
          subtitle="Projected platform revenue for the next 30 days using the latest transaction history"
        />

        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Store momentum radar</div>
              <div className="card-subtitle">Tenants the model expects to shape near-term revenue</div>
            </div>
            {aiOverview?.forecast?.signal && (
              <span className={`badge ${getForecastSignalBadge(aiOverview.forecast.signal)}`}>
                {getForecastSignalLabel(aiOverview.forecast.signal)}
              </span>
            )}
          </div>

          <div className="analytics-watch-list">
            {tenantSignals.length === 0 ? (
              <div className="analytics-watch-empty">
                Forecast signals will appear when stores accumulate enough recent sales data.
              </div>
            ) : (
              tenantSignals.map((tenant) => (
                <Link key={tenant.tenantId} href={`/tenants/${tenant.tenantId}`} className="analytics-watch-item">
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                      <strong>{tenant.businessName}</strong>
                      <span className={`badge ${getForecastSignalBadge(tenant.signal)}`}>
                        {getForecastSignalLabel(tenant.signal)}
                      </span>
                    </div>
                    <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                      Forecasted 30-day revenue {formatCurrency(tenant.projectedRevenue30d, { compact: true })} from {tenant.transactions30d} recent transactions
                    </div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontWeight: 700 }}>{formatPercent(tenant.deltaPercent30d)}</div>
                    <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>vs 30-day baseline</div>
                  </div>
                </Link>
              ))
            )}
          </div>

          <div className="ai-note-panel" style={{ marginTop: 18 }}>
            The forecast blends recency-weighted revenue smoothing with weekday seasonality, then pairs it with stock movement signals to prioritize operational follow-up.
          </div>
        </div>
      </div>

      <RestockRecommendationsPanel
        restock={aiOverview?.restock}
        showTenant
        title="AI Restocking Recommendations"
        subtitle="Cross-tenant product watchlist for preventing stockouts and limiting overstock"
      />

      <div className="grid-main-side" style={{ marginBottom: 20 }}>
        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Daily signup momentum</div>
              <div className="card-subtitle">Last 30 days of new tenant registrations</div>
            </div>
            <span className="badge badge-purple">{Number(summary.new_tenants_30d || 0)} new in 30 days</span>
          </div>

          <div className="chart-container-lg">
            {dailySeries.data.some((value) => value > 0) ? (
              <Line
                data={signupChartData}
                options={CHART_DEFAULTS}
              />
            ) : (
              <div className="empty-state">
                <div className="empty-icon">::</div>
                <h3>No signup movement yet</h3>
                <p>New registrations will populate this chart automatically.</p>
              </div>
            )}
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Account status mix</div>
              <div className="card-subtitle">Distribution of current tenant health</div>
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'center', height: 220 }}>
            <Doughnut
              data={statusMixData}
              options={{
                maintainAspectRatio: false,
                plugins: {
                  legend: {
                    display: true,
                    position: 'bottom',
                    labels: { color: '#94a3b8', font: { size: 12 }, padding: 16 },
                  },
                  tooltip: CHART_DEFAULTS.plugins.tooltip,
                },
                cutout: '68%',
              }}
            />
          </div>

          <div style={{ marginTop: 16 }}>
            {STATUS_ORDER.map((status, index) => (
              <div key={status} className="info-row">
                <span className="info-row-label">
                  <span className={`badge ${STATUS_BADGES[status]}`}>{STATUS_LABELS[status]}</span>
                </span>
                <span className="info-row-value">{statusCounts[index]} stores</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="grid-2" style={{ marginBottom: 20 }}>
        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Revenue by subscription tier</div>
              <div className="card-subtitle">How much tenant revenue each plan is generating</div>
            </div>
          </div>

          <div className="chart-container">
            <Bar
              data={tierRevenueData}
              options={{
                ...CHART_DEFAULTS,
                scales: {
                  ...CHART_DEFAULTS.scales,
                  y: {
                    ...CHART_DEFAULTS.scales.y,
                    ticks: {
                      color: '#475569',
                      font: { size: 11 },
                      callback: (value) => formatCurrency(value, { compact: true }),
                    },
                  },
                },
              }}
            />
          </div>

          <div style={{ marginTop: 16 }}>
            {TIER_ORDER.map((tier, index) => (
              <div key={tier} className="info-row">
                <span className="info-row-label">
                  <span className={`badge ${TIER_BADGES[tier]}`}>{TIER_LABELS[tier]}</span>
                </span>
                <span className="info-row-value">{formatCurrency(tierRevenue[index], { compact: true })}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Tenant acquisition trend</div>
              <div className="card-subtitle">Monthly registrations over the last 6 months</div>
            </div>
          </div>

          <div className="chart-container">
            <Bar
              data={monthlyAcquisitionData}
              options={CHART_DEFAULTS}
            />
          </div>

          <div className="analytics-inline-stats">
            <div className="analytics-inline-stat">
              <span className="analytics-inline-label">Recent signups</span>
              <strong>{Number(summary.new_tenants_30d || 0)}</strong>
            </div>
            <div className="analytics-inline-stat">
              <span className="analytics-inline-label">Total users</span>
              <strong>{Number(summary.total_users || 0).toLocaleString()}</strong>
            </div>
            <div className="analytics-inline-stat">
              <span className="analytics-inline-label">Tracked tenants</span>
              <strong>{tenants.length}</strong>
            </div>
          </div>
        </div>
      </div>

      <div className="analytics-insights-grid">
        {insightCards.map((card) => (
          <div key={card.title} className="analytics-insight-card">
            <div className="analytics-insight-label">{card.title}</div>
            <div className="analytics-insight-value">{card.value}</div>
            <div className="analytics-insight-meta">{card.meta}</div>
          </div>
        ))}
      </div>

      <div className="grid-main-side">
        <div className="card" style={{ padding: 0 }}>
          <div style={{ padding: '20px 20px 0' }}>
            <div className="card-title">Top performing stores</div>
            <div className="card-subtitle" style={{ marginBottom: 16 }}>
              Ranked by total recorded revenue, with transaction volume as the tiebreaker
            </div>
          </div>

          <div className="table-wrapper">
            <table>
              <thead>
                <tr>
                  <th>Rank</th>
                  <th>Store</th>
                  <th>Tier</th>
                  <th>Status</th>
                  <th>Transactions</th>
                  <th>Revenue</th>
                  <th>Joined</th>
                </tr>
              </thead>
              <tbody>
                {topStores.length === 0 ? (
                  <tr>
                    <td colSpan={7}>
                      <div className="empty-state">
                        <div className="empty-icon">--</div>
                        <h3>No tenant rankings yet</h3>
                        <p>Stores will appear here after data starts flowing.</p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  topStores.map((tenant, index) => (
                    <tr key={tenant.id}>
                      <td>
                        <span className="analytics-rank-pill">#{index + 1}</span>
                      </td>
                      <td>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                          <Link href={`/tenants/${tenant.id}`} style={{ fontWeight: 600 }}>
                            {tenant.business_name}
                          </Link>
                          <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>{tenant.owner_email}</span>
                        </div>
                      </td>
                      <td>
                        <span className={`badge ${TIER_BADGES[tenant.subscription_tier] || 'badge-gray'}`}>
                          {TIER_LABELS[tenant.subscription_tier] || tenant.subscription_tier}
                        </span>
                      </td>
                      <td>
                        <span className={`badge ${STATUS_BADGES[tenant.subscription_status] || 'badge-gray'}`}>
                          {STATUS_LABELS[tenant.subscription_status] || tenant.subscription_status}
                        </span>
                      </td>
                      <td>{Number(tenant.transaction_count || 0).toLocaleString()}</td>
                      <td style={{ fontWeight: 700 }}>{formatCurrency(tenant.total_revenue)}</td>
                      <td style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{formatDate(tenant.created_at)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Segment snapshot</div>
              <div className="card-subtitle">Plan mix, pricing influence, and watch-list stores</div>
            </div>
          </div>

          <div style={{ marginBottom: 20 }}>
            {TIER_ORDER.map((tier) => {
              const count =
                tier === 'free'
                  ? Number(summary.free_tenants || 0)
                  : tier === 'pro'
                    ? Number(summary.pro_tenants || 0)
                    : Number(summary.enterprise_tenants || 0);

              const share = safeDivide(count * 100, totalTenants);

              return (
                <div key={tier} className="analytics-progress-row">
                  <div className="analytics-progress-copy">
                    <span className={`badge ${TIER_BADGES[tier]}`}>{TIER_LABELS[tier]}</span>
                    <span>{count} stores</span>
                  </div>
                  <div className="analytics-progress-track">
                    <div
                      className="analytics-progress-fill"
                      style={{ width: `${Math.max(share, 3)}%` }}
                    />
                  </div>
                  <div className="analytics-progress-value">{formatPercent(share)}</div>
                </div>
              );
            })}
          </div>

          <div className="card-title" style={{ marginBottom: 10 }}>Needs review</div>
          <div className="analytics-watch-list">
            {tenants
              .filter((tenant) => ['inactive', 'suspended'].includes(tenant.subscription_status))
              .slice(0, 5)
              .map((tenant) => (
                <Link key={tenant.id} href={`/tenants/${tenant.id}`} className="analytics-watch-item">
                  <div>
                    <div style={{ fontWeight: 600 }}>{tenant.business_name}</div>
                    <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{tenant.owner_email}</div>
                  </div>
                  <span className={`badge ${STATUS_BADGES[tenant.subscription_status]}`}>
                    {STATUS_LABELS[tenant.subscription_status]}
                  </span>
                </Link>
              ))}

            {attentionStores === 0 && (
              <div className="analytics-watch-empty">
                All stores are active or cancelled. Nothing is waiting for intervention right now.
              </div>
            )}
          </div>
        </div>
      </div>
    </AppShell>
  );
}
