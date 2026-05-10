import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/owner_theme.dart';
import '../../widgets/owner_assistant_bubble.dart';
import '../../widgets/owner_bottom_bar.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _period = 'Week';
  final _periods = ['Today', 'Week', 'Month', 'Year'];

  // Stub chart data
  final _revenueData = [
    FlSpot(0, 2200),
    FlSpot(1, 3100),
    FlSpot(2, 2800),
    FlSpot(3, 3600),
    FlSpot(4, 3200),
    FlSpot(5, 4800),
    FlSpot(6, 4250),
  ];

  final _profitData = [
    FlSpot(0, 820),
    FlSpot(1, 1200),
    FlSpot(2, 950),
    FlSpot(3, 1400),
    FlSpot(4, 1100),
    FlSpot(5, 2100),
    FlSpot(6, 1820),
  ];

  final _topProducts = [
    {'name': 'Lucky Me Spicy', 'value': 640.0},
    {'name': 'C2 Green Tea', 'value': 480.0},
    {'name': 'Chippy BBQ', 'value': 360.0},
    {'name': 'Bear Brand', 'value': 320.0},
    {'name': 'Milo Sachet', 'value': 280.0},
  ];

  final _expenseCategories = [
    {'name': 'Restocking', 'pct': 0.52, 'color': OwnerTheme.primary},
    {'name': 'Utilities', 'pct': 0.22, 'color': Color(0xFFF59E0B)},
    {'name': 'Packaging', 'pct': 0.14, 'color': Color(0xFF10B981)},
    {'name': 'Others', 'pct': 0.12, 'color': Color(0xFF94A3B8)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OwnerTheme.background,
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: OwnerTheme.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 2.h),

            // Period selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _periods.map((p) {
                  final sel = p == _period;
                  return GestureDetector(
                    onTap: () => setState(() => _period = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? OwnerTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color:
                                sel ? OwnerTheme.primary : OwnerTheme.border),
                      ),
                      child: Text(p,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? Colors.white
                                  : OwnerTheme.textSecondary)),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: 2.5.h),

            // Summary Row
            Row(
              children: [
                _StatCard(
                    label: 'Revenue',
                    value: '₱23,580',
                    change: '+18%',
                    up: true),
                SizedBox(width: 3.w),
                _StatCard(
                    label: 'Profit', value: '₱9,440', change: '+12%', up: true),
                SizedBox(width: 3.w),
                _StatCard(
                    label: 'Expenses',
                    value: '₱3,820',
                    change: '+4%',
                    up: false),
              ],
            ),

            SizedBox(height: 2.5.h),

            // Revenue vs Profit chart
            _ChartCard(
              title: 'Revenue vs Profit',
              subtitle: 'This $_period',
              child: SizedBox(
                height: 20.h,
                child: LineChart(LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
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
                          const d = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          final i = v.toInt();
                          if (i < 0 || i >= d.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(d[i],
                              style: GoogleFonts.inter(
                                  fontSize: 10, color: OwnerTheme.textMuted));
                        },
                        reservedSize: 20,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _revenueData,
                      isCurved: true,
                      color: OwnerTheme.primary,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                          show: true,
                          color: OwnerTheme.primary.withValues(alpha: 0.07)),
                    ),
                    LineChartBarData(
                      spots: _profitData,
                      isCurved: true,
                      color: OwnerTheme.accent,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                          show: true,
                          color: OwnerTheme.accent.withValues(alpha: 0.07)),
                    ),
                  ],
                  minY: 0,
                )),
              ),
            ),

            SizedBox(height: 1.5.h),

            // Top products bar chart
            _ChartCard(
              title: 'Top Products',
              subtitle: 'By revenue',
              child: Column(
                children: _topProducts.asMap().entries.map((e) {
                  final pct = (e.value['value'] as double) / 700;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24.w,
                          child: Text(e.value['name'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: OwnerTheme.textSecondary),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 8,
                              backgroundColor: OwnerTheme.surfaceVariant,
                              valueColor:
                                  AlwaysStoppedAnimation(OwnerTheme.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                            '₱${(e.value['value'] as double).toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: OwnerTheme.textPrimary)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: 1.5.h),

            // Expense breakdown
            _ChartCard(
              title: 'Expense Breakdown',
              subtitle: 'By category',
              child: Column(
                children: _expenseCategories
                    .map((cat) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: cat['color'] as Color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(cat['name'] as String,
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: OwnerTheme.textPrimary))),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: SizedBox(
                                  width: 20.w,
                                  child: LinearProgressIndicator(
                                    value: cat['pct'] as double,
                                    minHeight: 6,
                                    backgroundColor: OwnerTheme.surfaceVariant,
                                    valueColor: AlwaysStoppedAnimation(
                                        cat['color'] as Color),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                  '${((cat['pct'] as double) * 100).toStringAsFixed(0)}%',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: OwnerTheme.textSecondary)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),

            SizedBox(height: 12.h),
          ],
        ),
      ),
      floatingActionButton: const OwnerAssistantBubble(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const OwnerBottomBar(currentIndex: 1),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, change;
  final bool up;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.change,
      required this.up});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OwnerTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10, color: OwnerTheme.textMuted)),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: OwnerTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(change,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: up ? OwnerTheme.accent : OwnerTheme.error)),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const _ChartCard(
      {required this.title, required this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OwnerTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OwnerTheme.textPrimary)),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: OwnerTheme.textMuted)),
            ],
          ),
          SizedBox(height: 1.5.h),
          child,
        ],
      ),
    );
  }
}
