'use client';
import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';
import Sidebar from './Sidebar';

export default function AppShell({ title, subtitle, children }) {
  const { admin, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && !admin) {
      router.push('/login');
    }
  }, [admin, loading, router]);

  if (loading) {
    return (
      <div className="loading-spinner" style={{ minHeight: '100vh' }}>
        <div className="spinner" />
        <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>Loading...</span>
      </div>
    );
  }

  if (!admin) return null;

  return (
    <div className="app-shell">
      <Sidebar />
      <div className="main-content">
        {/* Topbar */}
        <header className="topbar">
          <div className="topbar-title">
            <h1>{title}</h1>
            {subtitle && <p>{subtitle}</p>}
          </div>
          <div className="topbar-actions">
            <div className="topbar-badge">API Online</div>
          </div>
        </header>

        {/* Page content */}
        <div className="page-body animate-in">
          {children}
        </div>
      </div>
    </div>
  );
}
