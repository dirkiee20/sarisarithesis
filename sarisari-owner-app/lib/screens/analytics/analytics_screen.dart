import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/owner_data_service.dart';
import '../../theme/owner_theme.dart';
import '../../widgets/owner_assistant_bubble.dart';
import '../../widgets/owner_bottom_bar.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _dataService = const OwnerDataService();
  String _period = 'Week';
  final _periods = ['Today', 'Week', 'Month', 'Year'];
  OwnerAnalyticsData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _dataService.loadAnalytics(_period);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load analytics.';
        _loading = false;
      });
    }
  }

  List<FlSpot> get _revenueData => _spots('revenue');
  List<FlSpot> get _profitData => _spots('profit');

  List<FlSpot> _spots(String key) {
    final trend = _data?.trend ?? const [];
    if (trend.isEmpty) return const [FlSpot(0, 0)];
    return trend.asMap().entries.map((entry) {
      final value = entry.value[key];
      final number = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '') ?? 0;
      return FlSpot(entry.key.toDouble(), number);
    }).toList();
  }

  List<Map<String, dynamic>> get _topProducts => _data?.topProducts ?? const [];

  double get _topProductMax {
    final values = _topProducts
        .map((item) => (item['value'] as num?)?.toDouble() ?? 0)
        .toList();
    if (values.isEmpty) return 1;
    return values
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, double.infinity)
        .toDouble();
  }

  List<Map<String, dynamic>> get _expenseCategories {
    final colors = [
      OwnerTheme.primary,
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF94A3B8),
    ];
    final categories = _data?.expenseCategories ?? const [];
    final total = categories.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] as num?)?.toDouble() ?? 0),
    );

    return categories.asMap().entries.map((entry) {
      final value = (entry.value['value'] as num?)?.toDouble() ?? 0;
      return {
        'name': entry.value['name'],
        'pct': total <= 0 ? 0.0 : value / total,
        'color': colors[entry.key % colors.length],
      };
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
        appBar: AppBar(
          title: const Text('Analytics'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
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
                  onPressed: _loadAnalytics,
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
                    onTap: () {
                      setState(() => _period = p);
                      _loadAnalytics();
                    },
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
                    value: _money(_data?.revenue ?? 0),
                    change: 'Live',
                    up: true),
                SizedBox(width: 3.w),
                _StatCard(
                    label: 'Profit',
                    value: _money(_data?.profit ?? 0),
                    change: 'Live',
                    up: true),
                SizedBox(width: 3.w),
                _StatCard(
                    label: 'Expenses',
                    value: _money(_data?.expenses ?? 0),
                    change: 'Live',
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
                                children: _topProducts.isEmpty
                    ? [
                        _InlineEmpty(
                            message:
                                'No product sales summaries have been synced.')
                      ]
                    : _topProducts.asMap().entries.map((e) {
                        final value =
                            (e.value['value'] as num?)?.toDouble() ?? 0;
                        final pct = value / _topProductMax;
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
                                    backgroundColor:
                                        OwnerTheme.surfaceVariant,
                                    valueColor: AlwaysStoppedAnimation(
                                        OwnerTheme.primary),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(_money(value),
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
                children: _expenseCategories.isEmpty
                    ? [
                        _InlineEmpty(
                            message:
                                'No expense summaries have been synced yet.')
                      ]
                    : _expenseCategories
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

class _InlineEmpty extends StatelessWidget {
  final String message;
  const _InlineEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        message,
        style: GoogleFonts.inter(fontSize: 12, color: OwnerTheme.textMuted),
      ),
    );
  }
}


