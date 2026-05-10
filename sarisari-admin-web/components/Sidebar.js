'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';

const NAV = [
  {
    section: 'Overview',
    items: [
      { href: '/dashboard', icon: '⬡', label: 'Dashboard' },
      { href: '/analytics', icon: '📈', label: 'Analytics' },
    ],
  },
  {
    section: 'Management',
    items: [
      { href: '/tenants', icon: '🏪', label: 'Tenants' },
      { href: '/subscriptions', icon: '💳', label: 'Subscriptions' },
      { href: '/users', icon: '👥', label: 'Users' },
    ],
  },
  {
    section: 'System',
    items: [
      { href: '/settings', icon: '⚙️', label: 'Settings' },
    ],
  },
];

export default function Sidebar() {
  const pathname = usePathname();
  const { admin, logout } = useAuth();

  const initials = admin?.fullName
    ? admin.fullName.split(' ').map((n) => n[0]).join('').slice(0, 2).toUpperCase()
    : 'SA';

  return (
    <aside className="sidebar">
      {/* Logo */}
      <div className="sidebar-logo">
        <div className="sidebar-logo-icon">🏪</div>
        <div className="sidebar-logo-text">
          <h2>Sarisari Pro</h2>
          <span>Software Owner</span>
        </div>
      </div>

      {/* Navigation */}
      <nav className="sidebar-nav">
        {NAV.map((section) => (
          <div key={section.section}>
            <p className="nav-section-label">{section.section}</p>
            {section.items.map((item) => {
              const active = pathname === item.href || pathname.startsWith(item.href + '/');
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`nav-item ${active ? 'active' : ''}`}
                >
                  <span className="nav-icon">{item.icon}</span>
                  {item.label}
                </Link>
              );
            })}
          </div>
        ))}
      </nav>

      {/* Footer */}
      <div className="sidebar-footer">
        <div className="sidebar-admin-card">
          <div className="admin-avatar">{initials}</div>
          <div className="admin-info">
            <p>{admin?.fullName || 'Platform Admin'}</p>
            <span>● Online</span>
          </div>
        </div>
        <button
          className="nav-item"
          onClick={logout}
          style={{ marginTop: 8, width: '100%', color: 'var(--danger)' }}
        >
          <span className="nav-icon">🚪</span>
          Sign Out
        </button>
      </div>
    </aside>
  );
}
