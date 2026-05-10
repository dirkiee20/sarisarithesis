import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/owner_theme.dart';
import '../../widgets/owner_assistant_bubble.dart';
import '../../widgets/owner_bottom_bar.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  static const _staff = [
    {
      'name': 'Maria Santos',
      'role': 'Cashier',
      'status': 'Active',
      'shift': 'Morning (6AM–2PM)',
      'sales': '₱12,400'
    },
    {
      'name': 'Jose Reyes',
      'role': 'Stock Manager',
      'status': 'Active',
      'shift': 'Morning (6AM–2PM)',
      'sales': '₱8,200'
    },
    {
      'name': 'Ana Cruz',
      'role': 'Cashier',
      'status': 'Active',
      'shift': 'Afternoon (2PM–10PM)',
      'sales': '₱9,800'
    },
    {
      'name': 'Pedro Garcia',
      'role': 'Cashier',
      'status': 'Day Off',
      'shift': 'Afternoon (2PM–10PM)',
      'sales': '₱7,100'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OwnerTheme.background,
      appBar: AppBar(
        title: const Text('Staff'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: OwnerTheme.border),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add staff — coming soon'))),
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
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        children: [
          // Summary row
          Row(
            children: [
              _StatTile(
                  label: 'Total Staff',
                  value: '4',
                  icon: Icons.people_rounded,
                  color: OwnerTheme.primary),
              SizedBox(width: 3.w),
              _StatTile(
                  label: 'On Duty',
                  value: '3',
                  icon: Icons.check_circle_rounded,
                  color: OwnerTheme.accent),
              SizedBox(width: 3.w),
              _StatTile(
                  label: 'Day Off',
                  value: '1',
                  icon: Icons.free_breakfast_rounded,
                  color: OwnerTheme.warning),
            ],
          ),
          SizedBox(height: 2.5.h),

          Text('All Staff Members',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OwnerTheme.textPrimary)),
          SizedBox(height: 1.h),

          ..._staff.map((s) => _StaffCard(staff: s)),
          SizedBox(height: 10.h),
        ],
      ),
      floatingActionButton: const OwnerAssistantBubble(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const OwnerBottomBar(currentIndex: 3),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: OwnerTheme.textPrimary)),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10, color: OwnerTheme.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final Map<String, dynamic> staff;
  const _StaffCard({required this.staff});

  @override
  Widget build(BuildContext context) {
    final active = staff['status'] == 'Active';
    final initials =
        (staff['name'] as String).split(' ').map((n) => n[0]).take(2).join();
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
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initials,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(staff['name'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: OwnerTheme.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(staff['status'] as String,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? OwnerTheme.accent
                                  : OwnerTheme.warning)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(staff['role'] as String,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: OwnerTheme.textMuted)),
                Text(staff['shift'] as String,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: OwnerTheme.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(staff['sales'] as String,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: OwnerTheme.primary)),
              Text('this week',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: OwnerTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
