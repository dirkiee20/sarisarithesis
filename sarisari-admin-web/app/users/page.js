'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import api from '@/lib/api';

const ROLE_COLORS = {
  owner: 'badge-purple',
  manager: 'badge-blue',
  staff: 'badge-gray',
  cashier: 'badge-amber',
};

function formatDate(value) {
  if (!value) return '—';
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
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export default function UsersPage() {
  const [users, setUsers] = useState([]);
  const [stats, setStats] = useState({});
  const [pagination, setPagination] = useState({});
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [page, setPage] = useState(1);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const params = { page, limit: 15 };
      if (search) params.search = search;
      if (roleFilter) params.role = roleFilter;
      if (statusFilter) params.status = statusFilter;

      const data = await api.getUsers(params);
      setUsers(data.users || []);
      setStats(data.stats || {});
      setPagination(data.pagination || {});
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, [page, roleFilter, statusFilter]);

  useEffect(() => {
    const timer = setTimeout(() => {
      setPage(1);
      fetchUsers();
    }, 400);

    return () => clearTimeout(timer);
  }, [search]);

  const kpis = [
    {
      label: 'Total Users',
      value: Number(stats.total_users || 0).toLocaleString(),
      icon: '👥',
      color: 'purple',
      change: `${pagination.total || 0} in current view`,
    },
    {
      label: 'Active Accounts',
      value: Number(stats.active_users || 0).toLocaleString(),
      icon: '✅',
      color: 'green',
      change: 'Currently enabled',
    },
    {
      label: 'Recent Logins',
      value: Number(stats.recent_logins_7d || 0).toLocaleString(),
      icon: '🕒',
      color: 'blue',
      change: 'Logged in during the last 7 days',
    },
    {
      label: 'Managers',
      value: Number(stats.managers || 0).toLocaleString(),
      icon: '🧭',
      color: 'amber',
      change: 'Platform-wide manager accounts',
    },
    {
      label: 'Frontline Staff',
      value: Number((stats.staff || 0) + (stats.cashiers || 0)).toLocaleString(),
      icon: '🏪',
      color: 'purple',
      change: `${Number(stats.cashiers || 0).toLocaleString()} cashier accounts`,
    },
    {
      label: 'Inactive Accounts',
      value: Number(stats.inactive_users || 0).toLocaleString(),
      icon: '⛔',
      color: 'red',
      change: 'Need review or reactivation',
    },
  ];

  const roleSummary = [
    { label: 'Owners', value: stats.owners || 0, badge: 'badge-purple' },
    { label: 'Managers', value: stats.managers || 0, badge: 'badge-blue' },
    { label: 'Staff', value: stats.staff || 0, badge: 'badge-gray' },
    { label: 'Cashiers', value: stats.cashiers || 0, badge: 'badge-amber' },
  ];

  return (
    <AppShell title="Users" subtitle="Platform-wide user directory across all tenant stores">
      <div className="page-header">
        <div className="page-header-left">
          <h1>Platform Users</h1>
          <p>Monitor every owner, manager, staff member, and cashier account in one place.</p>
        </div>
      </div>

      <div className="kpi-grid">
        {kpis.map((kpi) => (
          <div key={kpi.label} className={`kpi-card ${kpi.color}`}>
            <div className={`kpi-icon ${kpi.color}`}>{kpi.icon}</div>
            <div className="kpi-value">{kpi.value}</div>
            <div className="kpi-label">{kpi.label}</div>
            <div className="kpi-change neutral">{kpi.change}</div>
          </div>
        ))}
      </div>

      <div className="grid-main-side" style={{ marginBottom: 20 }}>
        <div className="card" style={{ padding: '16px 20px' }}>
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'center' }}>
            <div className="search-bar" style={{ flex: 1, minWidth: 220 }}>
              <span className="search-icon">🔍</span>
              <input
                type="text"
                placeholder="Search by name, email, or store..."
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                style={{ width: '100%' }}
              />
            </div>

            <select
              className="form-select"
              value={roleFilter}
              onChange={(event) => {
                setRoleFilter(event.target.value);
                setPage(1);
              }}
              style={{ width: 150 }}
            >
              <option value="">All Roles</option>
              <option value="owner">Owner</option>
              <option value="manager">Manager</option>
              <option value="staff">Staff</option>
              <option value="cashier">Cashier</option>
            </select>

            <select
              className="form-select"
              value={statusFilter}
              onChange={(event) => {
                setStatusFilter(event.target.value);
                setPage(1);
              }}
              style={{ width: 150 }}
            >
              <option value="">All Statuses</option>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
            </select>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Role Mix</div>
              <div className="card-subtitle">Current platform-wide account breakdown</div>
            </div>
          </div>

          {roleSummary.map((item) => (
            <div key={item.label} className="info-row">
              <span className="info-row-label">
                <span className={`badge ${item.badge}`}>{item.label}</span>
              </span>
              <span className="info-row-value">{Number(item.value).toLocaleString()} users</span>
            </div>
          ))}
        </div>
      </div>

      <div className="card" style={{ padding: 0 }}>
        <div style={{ padding: '20px 20px 0' }}>
          <div className="card-title">User Directory</div>
          <div className="card-subtitle" style={{ marginBottom: 16 }}>
            {pagination.total || 0} matching user{pagination.total === 1 ? '' : 's'}
          </div>
        </div>

        <div className="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>User</th>
                <th>Role</th>
                <th>Status</th>
                <th>Store</th>
                <th>Plan</th>
                <th>Last Login</th>
                <th>Joined</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: 48 }}>
                    <div className="spinner" style={{ margin: '0 auto' }} />
                  </td>
                </tr>
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={7}>
                    <div className="empty-state">
                      <div className="empty-icon">👤</div>
                      <h3>No users found</h3>
                      <p>Try changing the filters or search terms.</p>
                    </div>
                  </td>
                </tr>
              ) : (
                users.map((user) => (
                  <tr key={user.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <div className="avatar avatar-sm">
                          {user.full_name?.charAt(0)?.toUpperCase() || '?'}
                        </div>
                        <div>
                          <div style={{ fontWeight: 600 }}>{user.full_name}</div>
                          <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{user.email}</div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${ROLE_COLORS[user.role] || 'badge-gray'}`}>
                        {user.role}
                      </span>
                    </td>
                    <td>
                      <span className={`badge ${user.is_active ? 'badge-green' : 'badge-red'}`}>
                        {user.is_active ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td>
                      <Link href={`/tenants/${user.tenant_id}`} style={{ fontWeight: 600 }}>
                        {user.business_name}
                      </Link>
                    </td>
                    <td>
                      <span className={`badge ${
                        user.subscription_tier === 'enterprise'
                          ? 'badge-green'
                          : user.subscription_tier === 'pro'
                            ? 'badge-purple'
                            : 'badge-gray'
                      }`}>
                        {user.subscription_tier}
                      </span>
                    </td>
                    <td style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                      {formatDateTime(user.last_login_at)}
                    </td>
                    <td style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                      {formatDate(user.created_at)}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {pagination.totalPages > 1 && (
          <div style={{ padding: '0 16px 16px' }}>
            <div className="pagination">
              <span className="pagination-info">
                Showing {((page - 1) * 15) + 1}–{Math.min(page * 15, pagination.total)} of {pagination.total}
              </span>
              <div className="pagination-controls">
                <button
                  className="page-btn"
                  onClick={() => setPage((current) => Math.max(1, current - 1))}
                  disabled={page === 1}
                >
                  ‹
                </button>
                {Array.from({ length: pagination.totalPages }, (_, index) => index + 1).map((pageNumber) => (
                  <button
                    key={pageNumber}
                    className={`page-btn ${pageNumber === page ? 'active' : ''}`}
                    onClick={() => setPage(pageNumber)}
                  >
                    {pageNumber}
                  </button>
                ))}
                <button
                  className="page-btn"
                  onClick={() => setPage((current) => Math.min(pagination.totalPages, current + 1))}
                  disabled={page === pagination.totalPages}
                >
                  ›
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </AppShell>
  );
}
