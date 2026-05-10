'use client';
import AppShell from '@/components/AppShell';
import { useAuth } from '@/lib/auth-context';

export default function SettingsPage() {
  const { admin } = useAuth();

  return (
    <AppShell title="Settings" subtitle="Platform configuration">
      <div style={{ maxWidth: 640 }}>

        {/* Admin Profile */}
        <div className="card" style={{ marginBottom: 20 }}>
          <div className="card-header">
            <div className="card-title">Platform Admin Profile</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 20,
            padding: '16px', background: 'var(--bg-elevated)', borderRadius: 'var(--radius-sm)' }}>
            <div className="avatar" style={{ width: 52, height: 52, fontSize: 20 }}>
              {admin?.fullName?.split(' ').map(n => n[0]).join('').slice(0,2).toUpperCase()}
            </div>
            <div>
              <div style={{ fontWeight: 700, fontSize: 16 }}>{admin?.fullName}</div>
              <div style={{ color: 'var(--text-secondary)', fontSize: 13 }}>{admin?.email}</div>
              <div style={{ marginTop: 6 }}><span className="badge badge-purple">Platform Administrator</span></div>
            </div>
          </div>
        </div>

        {/* API Configuration */}
        <div className="card" style={{ marginBottom: 20 }}>
          <div className="card-header">
            <div className="card-title">API Configuration</div>
          </div>
          {[
            {
              label: 'API Endpoint',
              value:
                process.env.NEXT_PUBLIC_API_URL ||
                'https://sarisarithesis-production.up.railway.app',
            },
            { label: 'Environment', value: process.env.NODE_ENV || 'development' },
          ].map(item => (
            <div key={item.label} className="info-row">
              <span className="info-row-label">{item.label}</span>
              <code style={{ fontSize: 12, background: 'var(--bg-elevated)',
                padding: '3px 8px', borderRadius: 4, color: 'var(--accent-light)' }}>
                {item.value}
              </code>
            </div>
          ))}
        </div>

        {/* Subscription Tier Pricing */}
        <div className="card" style={{ marginBottom: 20 }}>
          <div className="card-header">
            <div className="card-title">Subscription Tier Pricing</div>
            <span className="badge badge-amber">Reference Only</span>
          </div>
          {[
            { tier: 'Free',       price: '₱0/month',   features: '50 products, 1 user, 30-day history' },
            { tier: 'Pro',        price: '₱299/month',  features: 'Unlimited products, 5 users, AI features' },
            { tier: 'Enterprise', price: '₱999/month',  features: 'Unlimited everything, priority support' },
          ].map(t => (
            <div key={t.tier} className="info-row" style={{ alignItems: 'flex-start', flexDirection: 'column', gap: 4 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%', alignItems: 'center' }}>
                <span className="info-row-label" style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: 13 }}>{t.tier}</span>
                <span className="info-row-value" style={{ color: 'var(--success)' }}>{t.price}</span>
              </div>
              <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>{t.features}</span>
            </div>
          ))}
        </div>

        {/* About */}
        <div className="card">
          <div className="card-header">
            <div className="card-title">About Sarisari Pro</div>
          </div>
          {[
            { label: 'Platform Version', value: 'v1.0.0' },
            { label: 'Dashboard Version', value: 'v1.0.0' },
            { label: 'Database', value: 'PostgreSQL 18 (Local)' },
          ].map(item => (
            <div key={item.label} className="info-row">
              <span className="info-row-label">{item.label}</span>
              <span className="info-row-value">{item.value}</span>
            </div>
          ))}
        </div>
      </div>
    </AppShell>
  );
}
