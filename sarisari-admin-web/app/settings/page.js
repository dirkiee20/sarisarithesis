'use client';
import AppShell from '@/components/AppShell';
import { useAuth } from '@/lib/auth-context';

export default function SettingsPage() {
  const { admin } = useAuth();
  const initials = admin?.fullName
    ?.split(' ')
    .map(n => n[0])
    .join('')
    .slice(0, 2)
    .toUpperCase() || 'SA';

  return (
    <AppShell title="Settings" subtitle="Platform configuration">
      <div className="settings-grid">
        <div className="settings-column">
          {/* Admin Profile */}
          <div className="card">
            <div className="card-header">
              <div className="card-title">Platform Admin Profile</div>
            </div>
            <div className="settings-profile-panel">
              <div className="avatar" style={{ width: 52, height: 52, fontSize: 20 }}>
                {initials}
              </div>
              <div className="settings-profile-meta">
                <div style={{ fontWeight: 700, fontSize: 16 }}>
                  {admin?.fullName || 'Platform Admin'}
                </div>
                <div style={{ color: 'var(--text-secondary)', fontSize: 13 }}>
                  {admin?.email || 'admin@sarisari.pro'}
                </div>
                <div style={{ marginTop: 6 }}>
                  <span className="badge badge-purple">Platform Administrator</span>
                </div>
              </div>
            </div>
          </div>

          {/* API Configuration */}
          <div className="card">
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
              <div key={item.label} className="info-row settings-info-row">
                <span className="info-row-label">{item.label}</span>
                <code className="settings-code">{item.value}</code>
              </div>
            ))}
          </div>
        </div>

        <div className="settings-column">
          {/* Subscription Tier Pricing */}
          <div className="card">
            <div className="card-header">
              <div className="card-title">Subscription Tier Pricing</div>
              <span className="badge badge-amber">Reference Only</span>
            </div>
            <div className="settings-tier-list">
              {[
                { tier: 'Free', price: '\u20B10/month', features: '50 products, 1 user, 30-day history' },
                { tier: 'Pro', price: '\u20B1299/month', features: 'Unlimited products, 5 users, AI features' },
                { tier: 'Enterprise', price: '\u20B1999/month', features: 'Unlimited everything, priority support' },
              ].map(t => (
                <div key={t.tier} className="settings-tier-card">
                  <div className="settings-tier-top">
                    <span className="settings-tier-name">{t.tier}</span>
                    <span className="settings-tier-price">{t.price}</span>
                  </div>
                  <span className="settings-tier-features">{t.features}</span>
                </div>
              ))}
            </div>
          </div>

          {/* About */}
          <div className="card">
            <div className="card-header">
              <div className="card-title">About Sarisari Pro</div>
            </div>
            {[
              { label: 'Platform Version', value: 'v1.0.0' },
              { label: 'Dashboard Version', value: 'v1.0.0' },
              { label: 'Database', value: 'PostgreSQL (Hosted)' },
            ].map(item => (
              <div key={item.label} className="info-row">
                <span className="info-row-label">{item.label}</span>
                <span className="info-row-value">{item.value}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </AppShell>
  );
}
