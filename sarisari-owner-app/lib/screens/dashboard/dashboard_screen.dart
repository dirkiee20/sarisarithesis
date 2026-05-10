import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _storeName = '';
  String _ownerName = '';
  String _tier = 'pro';

  // Stub KPI data — replace with API when wired
  final _kpis = [
    {
      'label': 'Today\'s Revenue',
      'value': '₱4,250',
      'change': '+12%',
      'up': true,
      'icon': Icons.payments_outlined,
      'color': const Color(0xFF4F46E5)
    },
    {
      'label': 'Total Profit',
      'value': '₱1,820',
      'change': '+8%',
      'up': true,
      'icon': Icons.trending_up_rounded,
      'color': const Color(0xFF10B981)
    },
    {
      'label': 'Expenses',
      'value': '₱640',
      'change': '-3%',
      'up': false,
      'icon': Icons.receipt_long_outlined,
      'color': const Color(0xFFF59E0B)
    },
    {
      'label': 'Transactions',
      'value': '38',
      'change': '+5',
      'up': true,
      'icon': Icons.shopping_bag_outlined,
      'color': const Color(0xFF0EA5E9)
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storeName = prefs.getString('owner_store') ?? 'My Store';
      _ownerName = prefs.getString('owner_name') ?? 'Owner';
      _tier = prefs.getString('owner_tier') ?? 'free';
    });
  }

  @override
  Widget build(BuildContext context) {
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
                        _MiniStat(label: 'Revenue', value: '₱4,250'),
                        _Divider(),
                        _MiniStat(label: 'Profit', value: '₱1,820'),
                        _Divider(),
                        _MiniStat(label: 'Orders', value: '38'),
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
                            spots: const [
                              FlSpot(0, 2200),
                              FlSpot(1, 3100),
                              FlSpot(2, 2800),
                              FlSpot(3, 3600),
                              FlSpot(4, 3200),
                              FlSpot(5, 4800),
                              FlSpot(6, 4250),
                            ],
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
                  _TopProductItem(
                      rank: 1,
                      name: 'Lucky Me Spicy',
                      revenue: '₱640',
                      qty: 32),
                  _TopProductItem(
                      rank: 2, name: 'C2 Green Tea', revenue: '₱480', qty: 24),
                  _TopProductItem(
                      rank: 3, name: 'Chippy BBQ', revenue: '₱360', qty: 18),
                  _TopProductItem(
                      rank: 4,
                      name: 'Bear Brand Milk',
                      revenue: '₱320',
                      qty: 16),
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
