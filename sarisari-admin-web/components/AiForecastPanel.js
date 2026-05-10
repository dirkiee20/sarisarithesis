'use client';

import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js';
import { Line } from 'react-chartjs-2';

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Tooltip, Legend, Filler);

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

function formatPercent(value) {
  const prefix = Number(value || 0) > 0 ? '+' : '';
  return `${prefix}${Number(value || 0).toFixed(1)}%`;
}

function getSignalBadge(signal) {
  if (signal === 'growth') return 'badge badge-green';
  if (signal === 'softening') return 'badge badge-amber';
  return 'badge badge-blue';
}

function getSignalLabel(signal) {
  if (signal === 'growth') return 'Growth';
  if (signal === 'softening') return 'Softening';
  return 'Stable';
}

export default function AiForecastPanel({
  forecast,
  title = 'AI Revenue Forecast',
  subtitle = 'Predicted revenue trend based on transaction history',
}) {
  const historicalSeries = forecast?.historicalSeries || [];
  const forecastSeries = forecast?.forecastSeries || [];

  if (
    !forecast ||
    forecast?.summary?.populatedDays === 0 ||
    (historicalSeries.length === 0 && forecastSeries.length === 0)
  ) {
    return (
      <div className="card">
        <div className="card-header">
          <div>
            <div className="card-title">{title}</div>
            <div className="card-subtitle">{subtitle}</div>
          </div>
        </div>

        <div className="empty-state">
          <div className="empty-icon">AI</div>
          <h3>Not enough data for a forecast yet</h3>
          <p>The forecast will appear after transaction history starts accumulating.</p>
        </div>
      </div>
    );
  }

  const labels = [...historicalSeries.map((entry) => entry.label), ...forecastSeries.map((entry) => entry.label)];
  const lastActual = historicalSeries[historicalSeries.length - 1]?.revenue ?? null;

  const chartData = {
    labels,
    datasets: [
      {
        label: 'Actual revenue',
        data: [...historicalSeries.map((entry) => entry.revenue), ...Array(forecastSeries.length).fill(null)],
        borderColor: '#38bdf8',
        backgroundColor: 'rgba(56, 189, 248, 0.12)',
        pointBackgroundColor: '#38bdf8',
        pointRadius: 2,
        borderWidth: 2,
        tension: 0.35,
        fill: true,
      },
      {
        label: 'Forecast revenue',
        data: [
          ...Array(Math.max(historicalSeries.length - 1, 0)).fill(null),
          lastActual,
          ...forecastSeries.map((entry) => entry.predictedRevenue),
        ],
        borderColor: '#6366f1',
        backgroundColor: 'rgba(99, 102, 241, 0.06)',
        pointBackgroundColor: '#818cf8',
        pointRadius: 2,
        borderDash: [6, 6],
        borderWidth: 2,
        tension: 0.35,
        fill: false,
      },
    ],
  };

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    interaction: { mode: 'index', intersect: false },
    plugins: {
      legend: {
        display: true,
        position: 'bottom',
        labels: {
          color: '#94a3b8',
          font: { size: 11 },
          padding: 16,
        },
      },
      tooltip: {
        backgroundColor: '#1a1a26',
        titleColor: '#f1f5f9',
        bodyColor: '#94a3b8',
        borderColor: 'rgba(255,255,255,0.08)',
        borderWidth: 1,
        callbacks: {
          label(context) {
            return `${context.dataset.label}: ${formatCurrency(context.parsed.y || 0)}`;
          },
        },
      },
    },
    scales: {
      x: {
        grid: { color: 'rgba(255,255,255,0.04)' },
        ticks: { color: '#475569', font: { size: 11 } },
      },
      y: {
        grid: { color: 'rgba(255,255,255,0.04)' },
        ticks: {
          color: '#475569',
          font: { size: 11 },
          callback(value) {
            return formatCurrency(value, { compact: true });
          },
        },
        beginAtZero: true,
      },
    },
  };

  const summary = forecast.summary || {};

  return (
    <div className="card">
      <div className="card-header">
        <div>
          <div className="card-title">{title}</div>
          <div className="card-subtitle">{subtitle}</div>
        </div>
        <div className="analytics-chip-row">
          <span className={getSignalBadge(forecast.signal)}>{getSignalLabel(forecast.signal)}</span>
          <span className="badge badge-purple">{Math.round((forecast.confidence || 0) * 100)}% confidence</span>
        </div>
      </div>

      <div className="chart-container-lg">
        <Line data={chartData} options={chartOptions} />
      </div>

      <div className="ai-stat-grid">
        <div className="analytics-inline-stat">
          <span className="analytics-inline-label">Forecast next 30d</span>
          <strong>{formatCurrency(summary.predictedRevenue30d)}</strong>
        </div>
        <div className="analytics-inline-stat">
          <span className="analytics-inline-label">Vs. last 30d</span>
          <strong>{formatPercent(summary.deltaPercent30d)}</strong>
        </div>
        <div className="analytics-inline-stat">
          <span className="analytics-inline-label">Peak forecast day</span>
          <strong>{summary.peakForecastDate || 'N/A'}</strong>
        </div>
        <div className="analytics-inline-stat">
          <span className="analytics-inline-label">Predicted next 7d</span>
          <strong>{formatCurrency(summary.predictedRevenue7d)}</strong>
        </div>
      </div>
    </div>
  );
}
