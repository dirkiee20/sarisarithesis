import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/owner_data_service.dart';
import '../../routes/app_routes.dart';
import '../../theme/owner_theme.dart';
import '../../widgets/owner_assistant_bubble.dart';
import '../../widgets/owner_bottom_bar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dataService = const OwnerDataService();
  OwnerDashboardData? _data;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _dataService.loadDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load dashboard data.';
        _loading = false;
      });
    }
  }

  String get _storeName => _data?.storeName ?? 'My Store';
  String get _ownerName => _data?.ownerName ?? 'Owner';
  String get _tier => _data?.tier ?? 'free';

  List<Map<String, dynamic>> get _kpis {
    final source = _data?.kpis ?? const [];
    final icons = [
      Icons.payments_outlined,
      Icons.trending_up_rounded,
      Icons.receipt_long_outlined,
      Icons.shopping_bag_outlined,
    ];
    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF0EA5E9),
    ];

    return List.generate(source.length, (index) {
      return {
        ...source[index],
        'icon': icons[index],
        'color': colors[index],
      };
    });
  }

  List<FlSpot> get _weeklyRevenueSpots {
    final daily = _data?.weeklyTrend ?? const [];
    if (daily.isEmpty) return const [FlSpot(0, 0)];
    return daily.asMap().entries.map((entry) {
      final revenue = entry.value['revenue'];
      final value = revenue is num
          ? revenue.toDouble()
          : double.tryParse(revenue?.toString() ?? '') ?? 0;
      return FlSpot(entry.key.toDouble(), value);
    }).toList();
  }

  String _money(num value) {
    final text = value.round().toString();
    final chars = text.split('').reversed.toList();
    final groups = <String>[];
    for (var i = 0; i < chars.length; i += 3) {
      groups.add(chars.skip(i).take(3).toList().reversed.join());
    }
    return '₱${groups.reversed.join(',')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: OwnerTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: OwnerTheme.background,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(6.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: OwnerTheme.textSecondary)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadDashboard,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: OwnerTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration:
                  const BoxDecoration(gradient: OwnerTheme.headerGradient),
              padding: EdgeInsets.fromLTRB(
                  5.w, MediaQuery.of(context).padding.top + 16, 5.w, 3.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Good morning 👋',
                                style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 13)),
                            Text(_ownerName,
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: OwnerTheme.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: OwnerTheme.primary.withValues(alpha: 0.4)),
                        ),
                        child: Text(_tier.toUpperCase(),
                            style: GoogleFonts.inter(
                                color: OwnerTheme.primaryLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Text(_storeName,
                      style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12)),
                  SizedBox(height: 2.h),

                  // Today's summary card
                  Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniStat(
                            label: 'Revenue',
                            value: _money(_data?.todayRevenue ?? 0)),
                        _Divider(),
                        _MiniStat(
                            label: 'Profit',
                            value: _money(_data?.todayProfit ?? 0)),
                        _Divider(),
                        _MiniStat(
                            label: 'Orders',
                            value: '${_data?.todayTransactions ?? 0}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── KPI Cards ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 2.5.h, 4.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle("Today's Performance"),
                  SizedBox(height: 1.h),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _kpis.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.55,
                      crossAxisSpacing: 3.w,
                      mainAxisSpacing: 3.w,
                    ),
                    itemBuilder: (_, i) => _KpiCard(data: _kpis[i]),
                  ),
                ],
              ),
            ),
          ),

          // ── Revenue Chart ─────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 2.5.h, 4.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Revenue This Week'),
                  SizedBox(height: 1.5.h),
                  Container(
                    height: 22.h,
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: OwnerTheme.border),
                    ),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1000,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: const Color(0xFFE2E8F0),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                const days = [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun'
                                ];
                                final idx = v.toInt();
                                if (idx < 0 || idx >= days.length) {
                                  return const SizedBox.shrink();
                                }
                                return Text(days[idx],
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: OwnerTheme.textMuted));
                              },
                              reservedSize: 24,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _weeklyRevenueSpots,
                            isCurved: true,
                            color: OwnerTheme.primary,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: OwnerTheme.primary.withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                        minY: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── AI Insights ──────────────────────────────
          if (_data?.aiInsights != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(4.w, 2.5.h, 4.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 20),
                        const SizedBox(width: 8),
                        const _SectionTitle('AI Forecast & Restock'),
                      ],
                    ),
                    SizedBox(height: 1.5.h),
                    _AiInsightsCard(insights: _data!.aiInsights!),
                  ],
                ),
              ),
            ),

          // ── Quick Actions ────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 2.5.h, 4.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Quick Actions'),
                  SizedBox(height: 1.h),
                  Row(
                    children: [
                      Expanded(
                          child: _QuickAction(
                              icon: Icons.analytics_rounded,
                              label: 'View Reports',
                              color: OwnerTheme.primary,
                              onTap: () => Navigator.pushReplacementNamed(
                                  context, AppRoutes.analytics))),
                      SizedBox(width: 3.w),
                      Expanded(
                          child: _QuickAction(
                              icon: Icons.people_rounded,
                              label: 'Manage Staff',
                              color: const Color(0xFF10B981),
                              onTap: () => Navigator.pushReplacementNamed(
                                  context, AppRoutes.staff))),
                      SizedBox(width: 3.w),
                      Expanded(
                          child: _QuickAction(
                              icon: Icons.receipt_long_rounded,
                              label: 'Expenses',
                              color: const Color(0xFFF59E0B),
                              onTap: () => Navigator.pushReplacementNamed(
                                  context, AppRoutes.expenses))),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Top Products ─────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 2.5.h, 4.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Top Products Today'),
                  SizedBox(height: 1.h),
                  if ((_data?.topProducts ?? const []).isEmpty)
                    _EmptyCard(
                      message:
                          'No cashier product summaries have been synced yet.',
                    )
                  else
                    ...(_data?.topProducts ?? const [])
                        .asMap()
                        .entries
                        .map((entry) {
                      final product = entry.value;
                      return _TopProductItem(
                        rank: entry.key + 1,
                        name: product['name'] as String,
                        revenue: product['revenue'] as String,
                        qty: product['qty'] as int,
                      );
                    }),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 12.h)),
        ],
      ),
      floatingActionButton: const OwnerAssistantBubble(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const OwnerBottomBar(currentIndex: 0),
    );
  }
}

// ── Helper widgets ───────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: OwnerTheme.textPrimary));
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
      ]);
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 30, color: Colors.white.withValues(alpha: 0.15));
}

class _KpiCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _KpiCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final color = data['color'] as Color;
    final up = data['up'] as bool;
    return Container(
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OwnerTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data['icon'] as IconData, color: color, size: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: up ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  data['change'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color:
                        up ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['value'] as String,
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: OwnerTheme.textPrimary)),
              Text(data['label'] as String,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: OwnerTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OwnerTheme.border),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(fontSize: 12, color: OwnerTheme.textMuted),
      ),
    );
  }
}

class _AiInsightsCard extends StatelessWidget {
  final Map<String, dynamic> insights;
  const _AiInsightsCard({required this.insights});

  String _money(num value) {
    final text = value.round().toString();
    final chars = text.split('').reversed.toList();
    final groups = <String>[];
    for (var i = 0; i < chars.length; i += 3) {
      groups.add(chars.skip(i).take(3).toList().reversed.join());
    }
    return '₱${groups.reversed.join(',')}';
  }

  @override
  Widget build(BuildContext context) {
    final forecast = insights['forecast']?['summary'] as Map<String, dynamic>?;
    final restock = insights['restock'] as Map<String, dynamic>?;
    final recommendations = restock?['recommendations'] as List<dynamic>? ?? [];

    final predicted30d = forecast?['predictedRevenue30d'] ?? 0;
    final delta30d = forecast?['deltaPercent30d'] ?? 0;
    final isUp = (delta30d as num) >= 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF5F3FF),
            Color(0xFFEDE9FE),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('30-Day Revenue Forecast',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF6D28D9),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_money(predicted30d as num),
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            color: const Color(0xFF4C1D95),
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
                          color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text('${(delta30d as num).abs().toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (recommendations.isNotEmpty) ...[
            Container(height: 1, color: const Color(0xFFDDD6FE)),
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Smart Restock Recommendations',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF6D28D9),
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...recommendations.take(3).map((item) {
                    final isCritical = item['priority'] == 'critical';
                    final qty = item['suggestedOrderQuantity'] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isCritical ? Icons.warning_rounded : Icons.info_outline,
                            color: isCritical ? const Color(0xFFEA580C) : const Color(0xFF8B5CF6),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: const Color(0xFF4C1D95)),
                                children: [
                                  TextSpan(
                                      text: '${item['productName']}: ',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  TextSpan(text: 'Order $qty units '),
                                  if (item['optimalRestockDate'] != null)
                                    TextSpan(text: 'by ${item['optimalRestockDate']}'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopProductItem extends StatelessWidget {
  final int rank;
  final String name, revenue;
  final int qty;
  const _TopProductItem(
      {required this.rank,
      required this.name,
      required this.revenue,
      required this.qty});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OwnerTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: rank == 1
                  ? const Color(0xFFFEF3C7)
                  : OwnerTheme.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Text('$rank',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: rank == 1
                            ? const Color(0xFFD97706)
                            : OwnerTheme.textSecondary))),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(name,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OwnerTheme.textPrimary))),
          Text('$qty sold',
              style:
                  GoogleFonts.inter(fontSize: 11, color: OwnerTheme.textMuted)),
          const SizedBox(width: 12),
          Text(revenue,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OwnerTheme.primary)),
        ],
      ),
    );
  }
}



