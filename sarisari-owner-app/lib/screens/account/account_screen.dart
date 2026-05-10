import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/owner_theme.dart';
import '../../widgets/owner_assistant_bubble.dart';
import '../../widgets/owner_bottom_bar.dart';
import '../../routes/app_routes.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _name = '', _email = '', _store = '', _tier = 'pro';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('owner_name') ?? 'Owner';
      _email = prefs.getString('owner_email') ?? '';
      _store = prefs.getString('owner_store') ?? 'My Store';
      _tier = prefs.getString('owner_tier') ?? 'free';
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Sign out of your owner account?',
            style: GoogleFonts.inter(
                fontSize: 14, color: OwnerTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: OwnerTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: OwnerTheme.error,
                foregroundColor: Colors.white),
            child: Text('Sign Out',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  Color _tierColor() {
    switch (_tier) {
      case 'pro':
        return OwnerTheme.primary;
      case 'enterprise':
        return OwnerTheme.accent;
      default:
        return OwnerTheme.textMuted;
    }
  }

  String _tierLabel() {
    switch (_tier) {
      case 'pro':
        return 'Pro Plan';
      case 'enterprise':
        return 'Enterprise';
      default:
        return 'Free Plan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    return Scaffold(
      backgroundColor: OwnerTheme.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              decoration:
                  const BoxDecoration(gradient: OwnerTheme.headerGradient),
              padding: EdgeInsets.fromLTRB(
                  5.w, MediaQuery.of(context).padding.top + 20, 5.w, 4.h),
              child: Column(
                children: [
                  Container(
                    width: 20.w,
                    height: 20.w,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFF4F46E5).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: Center(
                        child: Text(initials,
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800))),
                  ),
                  SizedBox(height: 1.5.h),
                  Text(_name,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 0.3.h),
                  Text(_email,
                      style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13)),
                  SizedBox(height: 1.5.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Badge(label: _tierLabel(), color: _tierColor()),
                      const SizedBox(width: 8),
                      _Badge(label: 'Owner', color: const Color(0xFF0EA5E9)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
              child: _SectionCard(title: 'Store Info', children: [
                _InfoRow(
                    icon: Icons.store_outlined,
                    label: 'Store Name',
                    value: _store),
                _InfoRow(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Plan',
                    value: _tierLabel(),
                    valueColor: _tierColor()),
                _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: _email.isNotEmpty ? _email : '—'),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0),
              child: _SectionCard(title: 'Navigation', children: [
                _ActionRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Expenses',
                    onTap: () => Navigator.pushReplacementNamed(
                        context, AppRoutes.expenses)),
                _ActionRow(
                    icon: Icons.assessment_outlined,
                    label: 'Reports',
                    onTap: () => Navigator.pushReplacementNamed(
                        context, AppRoutes.reports)),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0),
              child: _SectionCard(title: 'Subscription', children: [
                _ActionRow(
                    icon: Icons.upgrade_rounded,
                    label: 'Upgrade Plan',
                    iconColor: OwnerTheme.primary,
                    labelColor: OwnerTheme.primary,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Upgrade — coming soon')))),
                _ActionRow(
                    icon: Icons.receipt_outlined,
                    label: 'Billing History',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Billing — coming soon')))),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded,
                      color: OwnerTheme.error, size: 20),
                  label: Text('Sign Out',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: OwnerTheme.error,
                          fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: const Color(0xFFFEF2F2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: const OwnerAssistantBubble(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const OwnerBottomBar(currentIndex: 4),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title.toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: OwnerTheme.textMuted,
                    letterSpacing: 0.8)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OwnerTheme.border),
            ),
            child: Column(children: children),
          ),
        ],
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon, size: 18, color: OwnerTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: OwnerTheme.textSecondary))),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? OwnerTheme.textPrimary)),
        ]),
      );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor, labelColor;
  final VoidCallback onTap;
  const _ActionRow(
      {required this.icon,
      required this.label,
      this.iconColor,
      this.labelColor,
      required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Icon(icon, size: 18, color: iconColor ?? OwnerTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: labelColor ?? OwnerTheme.textPrimary))),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: Color(0xFFCBD5E1)),
          ]),
        ),
      );
}
