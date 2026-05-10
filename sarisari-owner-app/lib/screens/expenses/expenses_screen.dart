import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/owner_data_service.dart';
import '../../routes/app_routes.dart';
import '../../theme/owner_theme.dart';
import '../../widgets/owner_assistant_bubble.dart';
import '../../widgets/owner_bottom_bar.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _dataService = const OwnerDataService();
  OwnerExpensesData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _dataService.loadExpenses();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load expense summaries.';
        _loading = false;
      });
    }
  }

  Future<void> _openAddExpense() async {
    final created = await Navigator.of(context).pushNamed(AppRoutes.addExpense);
    if (created == true) {
      await _loadExpenses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added successfully')),
      );
    }
  }

  String _money(num value) {
    final text = value.round().toString();
    final chars = text.split('').reversed.toList();
    final groups = <String>[];
    for (var i = 0; i < chars.length; i += 3) {
      groups.add(chars.skip(i).take(3).toList().reversed.join());
    }
    return '\u20B1${groups.reversed.join(',')}';
  }

  Color _catColor(String c) {
    switch (c) {
      case 'Restocking':
        return OwnerTheme.primary;
      case 'Utilities':
        return OwnerTheme.warning;
      case 'Packaging':
        return OwnerTheme.accent;
      default:
        return OwnerTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OwnerTheme.background,
      appBar: AppBar(
        title: const Text('Expenses'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: OwnerTheme.border),
        ),
        actions: [
          TextButton.icon(
            onPressed: _openAddExpense,
            icon: const Icon(Icons.add_rounded,
                size: 18, color: OwnerTheme.primary),
            label: Text('Add',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: OwnerTheme.primary)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ExpenseMessage(message: _error!, onRetry: _loadExpenses)
              : ListView(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  children: [
                    // Summary
                    Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ExpStat(
                              label: 'This Month',
                              value: _money(_data?.monthTotal ?? 0)),
                          Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withValues(alpha: 0.2)),
                          _ExpStat(
                              label: 'This Week',
                              value: _money(_data?.weekTotal ?? 0)),
                          Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withValues(alpha: 0.2)),
                          _ExpStat(
                              label: 'Today',
                              value: _money(_data?.todayTotal ?? 0)),
                        ],
                      ),
                    ),
                    SizedBox(height: 2.5.h),

                    Text('Recent Expenses',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OwnerTheme.textPrimary)),
                    SizedBox(height: 1.h),

                    if ((_data?.expenses ?? const []).isEmpty)
                      const _ExpenseEmptyCard(
                        message: 'No expense summaries have been synced yet.',
                      )
                    else
                      ...(_data?.expenses ?? const []).map((e) {
                        final cat = e['cat'] ?? 'General';
                        final catColor = _catColor(cat);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: OwnerTheme.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.receipt_outlined,
                                    color: catColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e['desc'] ?? '$cat summary',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: OwnerTheme.textPrimary)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: catColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(cat,
                                          style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: catColor)),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(e['amount'] ?? _money(0),
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: OwnerTheme.textPrimary)),
                                  Text(e['date'] ?? '',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: OwnerTheme.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    SizedBox(height: 10.h),
                  ],
                ),
      floatingActionButton: const OwnerAssistantBubble(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const OwnerBottomBar(currentIndex: 3),
    );
  }
}

class _ExpenseMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ExpenseMessage({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.inter(fontSize: 13, color: OwnerTheme.textMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpenseEmptyCard extends StatelessWidget {
  final String message;
  const _ExpenseEmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OwnerTheme.border),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(fontSize: 12, color: OwnerTheme.textMuted),
      ),
    );
  }
}

class _ExpStat extends StatelessWidget {
  final String label, value;
  const _ExpStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
      ]);
}
