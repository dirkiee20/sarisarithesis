'use client';

import Link from 'next/link';

function formatNumber(value, digits = 0) {
  return Number(value || 0).toLocaleString('en-PH', {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  });
}

function getPriorityBadge(priority) {
  if (priority === 'critical') return 'badge badge-red';
  if (priority === 'high') return 'badge badge-amber';
  if (priority === 'medium') return 'badge badge-blue';
  return 'badge badge-gray';
}

function getActionLabel(actionType) {
  if (actionType === 'restock_now') return 'Restock now';
  if (actionType === 'restock_soon') return 'Restock soon';
  if (actionType === 'overstock_risk') return 'Overstock risk';
  if (actionType === 'slow_moving') return 'Slow moving';
  return 'Healthy';
}

export default function RestockRecommendationsPanel({
  restock,
  title = 'AI Restocking Recommendations',
  subtitle = 'Recommended timing and quantities to avoid stockouts and overstocking',
  showTenant = false,
}) {
  const summary = restock?.summary || {};
  const recommendations = restock?.recommendations || [];

  return (
    <div className="card">
      <div className="card-header">
        <div>
          <div className="card-title">{title}</div>
          <div className="card-subtitle">{subtitle}</div>
        </div>
        <div className="analytics-chip-row">
          <span className="badge badge-red">{summary.critical || 0} critical</span>
          <span className="badge badge-amber">{summary.high || 0} high</span>
          <span className="badge badge-blue">{summary.overstockRisk || 0} overstock watch</span>
        </div>
      </div>

      <div className="ai-stat-grid" style={{ marginBottom: 20 }}>
        <div className="analytics-inline-stat">
          <span className="analytics-inline-label">Products reviewed</span>
          <strong>{formatNumber(summary.totalProducts || 0)}</strong>
        </div>
        <div className="analytics-inline-stat">
          <span className="analytics-inline-label">Actionable</span>
          <strong>{formatNumber(summary.actionable || 0)}</strong>
        </div>
        <div className="analytics-inline-stat">
          <span className="analytics-inline-label">Stockout risk</span>
          <strong>{formatNumber(summary.stockoutRisk || 0)}</strong>
        </div>
        <div className="analytics-inline-stat">
          <span className="analytics-inline-label">Planned restocks</span>
          <strong>{formatNumber(summary.plannedRestocks || 0)}</strong>
        </div>
      </div>

      {recommendations.length === 0 ? (
        <div className="empty-state">
          <div className="empty-icon">OK</div>
          <h3>No urgent restocking actions right now</h3>
          <p>The current stock profile is healthy based on recent product movement.</p>
        </div>
      ) : (
        <div className="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>Priority</th>
                <th>Product</th>
                {showTenant && <th>Store</th>}
                <th>Stock</th>
                <th>Demand/day</th>
                <th>Cover</th>
                <th>Suggested Qty</th>
                <th>Restock By</th>
              </tr>
            </thead>
            <tbody>
              {recommendations.map((item) => (
                <tr key={`${item.tenantId}-${item.productId}`}>
                  <td>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                      <span className={getPriorityBadge(item.priority)}>{item.priority}</span>
                      <span className="badge badge-gray">{getActionLabel(item.actionType)}</span>
                    </div>
                  </td>
                  <td>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                      <strong>{item.productName}</strong>
                      <span style={{ color: 'var(--text-secondary)', fontSize: 12 }}>{item.category}</span>
                      <span style={{ color: 'var(--text-muted)', fontSize: 12 }}>{item.message}</span>
                    </div>
                  </td>
                  {showTenant && (
                    <td>
                      <Link href={`/tenants/${item.tenantId}`} style={{ fontWeight: 600 }}>
                        {item.businessName}
                      </Link>
                    </td>
                  )}
                  <td>{formatNumber(item.currentStock)}</td>
                  <td>{formatNumber(item.dailyDemand, 2)}</td>
                  <td>{item.stockCoverageDays === null ? 'N/A' : `${formatNumber(item.stockCoverageDays, 1)} days`}</td>
                  <td>{formatNumber(item.suggestedOrderQuantity || 0)}</td>
                  <td>{item.optimalRestockDate || 'Monitor'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
