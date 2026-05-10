import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_export.dart';
import '../../widgets/cashier_assistant_bubble.dart';
import '../../widgets/custom_bottom_bar.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _userName = '';
  String _userEmail = '';
  String _userRole = '';
  String _tenantName = '';
  String _subscriptionTier = 'free';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('auth_user_name') ?? 'Store Owner';
      _userEmail = prefs.getString('auth_user_email') ?? '';
      _userRole = prefs.getString('auth_user_role') ?? 'owner';
      _tenantName = prefs.getString('auth_tenant_name') ?? 'My Store';
      _subscriptionTier = prefs.getString('auth_subscription_tier') ?? 'free';
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to sign out of SariSari Pro?',
          style:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Clear all session data
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
  }

  Color _tierColor() {
    switch (_subscriptionTier.toLowerCase()) {
      case 'pro':
        return const Color(0xFF7C3AED);
      case 'enterprise':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _tierLabel() {
    switch (_subscriptionTier.toLowerCase()) {
      case 'pro':
        return 'Pro Plan';
      case 'enterprise':
        return 'Enterprise Plan';
      default:
        return 'Free Plan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _userName.isNotEmpty
        ? _userName
            .trim()
            .split(' ')
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'SP';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // ── Hero Header ────────────────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1E293B), Color(0xFF334155)],
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(5.w, 3.h, 5.w, 4.h),
                      child: Column(
                        children: [
                          // Avatar
                          Container(
                            width: 22.w,
                            height: 22.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 1.5.h),

                          Text(
                            _userName.isNotEmpty ? _userName : 'Store Owner',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),

                          Text(
                            _userEmail.isNotEmpty
                                ? _userEmail
                                : 'Not connected yet',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 1.5.h),

                          // Tier + Role badges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Badge(
                                label: _tierLabel(),
                                color: _tierColor(),
                              ),
                              const SizedBox(width: 8),
                              _Badge(
                                label: _userRole.isNotEmpty
                                    ? _userRole[0].toUpperCase() +
                                        _userRole.substring(1)
                                    : 'Owner',
                                color: const Color(0xFF0EA5E9),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Store info ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
                      child: _SectionCard(
                        title: 'Store Info',
                        children: [
                          _InfoTile(
                            icon: Icons.store_outlined,
                            label: 'Store Name',
                            value: _tenantName.isNotEmpty ? _tenantName : '—',
                          ),
                          _InfoTile(
                            icon: Icons.workspace_premium_outlined,
                            label: 'Subscription',
                            value: _tierLabel(),
                            valueColor: _tierColor(),
                          ),
                          _InfoTile(
                            icon: Icons.admin_panel_settings_outlined,
                            label: 'Your Role',
                            value: _userRole.isNotEmpty
                                ? _userRole[0].toUpperCase() +
                                    _userRole.substring(1)
                                : 'Owner',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── App settings ────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0),
                      child: _SectionCard(
                        title: 'App Settings',
                        children: [
                          _ActionTile(
                            icon: Icons.notifications_outlined,
                            label: 'Notifications',
                            onTap: () => _showComingSoon('Notifications'),
                          ),
                          _ActionTile(
                            icon: Icons.color_lens_outlined,
                            label: 'Appearance',
                            onTap: () => _showComingSoon('Appearance'),
                          ),
                          _ActionTile(
                            icon: Icons.language_outlined,
                            label: 'Language',
                            trailing: Text(
                              'English',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            onTap: () => _showComingSoon('Language'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Subscription ────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0),
                      child: _SectionCard(
                        title: 'Subscription & Billing',
                        children: [
                          _ActionTile(
                            icon: Icons.upgrade_rounded,
                            label: 'Upgrade Plan',
                            iconColor: const Color(0xFF4F46E5),
                            labelColor: const Color(0xFF4F46E5),
                            onTap: () => _showComingSoon('Upgrade Plan'),
                          ),
                          _ActionTile(
                            icon: Icons.receipt_long_outlined,
                            label: 'Billing History',
                            onTap: () => _showComingSoon('Billing History'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Support ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0),
                      child: _SectionCard(
                        title: 'Support',
                        children: [
                          _ActionTile(
                            icon: Icons.help_outline_rounded,
                            label: 'Help Center',
                            onTap: () => _showComingSoon('Help Center'),
                          ),
                          _ActionTile(
                            icon: Icons.info_outline_rounded,
                            label: 'About SariSari Pro',
                            trailing: Text(
                              'v1.0.0',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Sign Out button ─────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded,
                              color: Color(0xFFEF4444), size: 20),
                          label: Text(
                            'Sign Out',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEF4444),
                              fontSize: 15,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFFFECACA), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: const Color(0xFFFEF2F2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: 3,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, AppRoutes.productsTab);
              break;
            case 1:
              Navigator.pushReplacementNamed(context, AppRoutes.analyticsTab);
              break;
            case 2:
              Navigator.pushReplacementNamed(
                  context, AppRoutes.stockManagementTab);
              break;
            case 3:
              break; // Already here
          }
        },
      ),
      floatingActionButton: const CashierAssistantBubble(),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }
}

// ─── Helper Widgets ─────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: valueColor ?? const Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.iconColor,
    this.labelColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? const Color(0xFF94A3B8)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: labelColor ?? const Color(0xFF1E293B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFFCBD5E1),
                ),
          ],
        ),
      ),
    );
  }
}
