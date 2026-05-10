import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/owner_theme.dart';
import '../../widgets/owner_assistant_bubble.dart';
import '../../widgets/owner_bottom_bar.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const _reports = [
    {
      'title': 'Sales Report',
      'desc': 'Daily, weekly & monthly sales breakdown',
      'icon': Icons.bar_chart_rounded,
      'color': Color(0xFF4F46E5)
    },
    {
      'title': 'Profit & Loss',
      'desc': 'Revenue, expenses and net income',
      'icon': Icons.account_balance_outlined,
      'color': Color(0xFF10B981)
    },
    {
      'title': 'Inventory Report',
      'desc': 'Stock levels and product movement',
      'icon': Icons.inventory_2_outlined,
      'color': Color(0xFF0EA5E9)
    },
    {
      'title': 'Staff Performance',
      'desc': 'Sales per staff member',
      'icon': Icons.people_outlined,
      'color': Color(0xFFF59E0B)
    },
    {
      'title': 'Expense Report',
      'desc': 'Operating costs by category',
      'icon': Icons.receipt_long_outlined,
      'color': Color(0xFFEF4444)
    },
    {
      'title': 'Customer Report',
      'desc': 'Purchase patterns and trends',
      'icon': Icons.person_search_outlined,
      'color': Color(0xFF8B5CF6)
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OwnerTheme.background,
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: OwnerTheme.border),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 12.h),
        children: [
          // Summary header
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.assessment_rounded,
                    color: Colors.white, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Business Reports',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(
                          'Generate and export detailed reports for your store',
                          style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 2.5.h),
          Text('Available Reports',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OwnerTheme.textPrimary)),
          SizedBox(height: 1.h),

          ..._reports.map((r) {
            final color = r['color'] as Color;
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(r['icon'] as IconData, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['title'] as String,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: OwnerTheme.textPrimary)),
                        Text(r['desc'] as String,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: OwnerTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('${r['title']} — coming soon'))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.download_rounded,
                                  color: color, size: 14),
                              const SizedBox(width: 4),
                              Text('Export',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: color)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
      floatingActionButton: const OwnerAssistantBubble(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const OwnerBottomBar(currentIndex: 3),
    );
  }
}
