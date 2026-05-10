import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../routes/app_routes.dart';
import '../theme/owner_theme.dart';

class OwnerBottomBar extends StatelessWidget {
  final int currentIndex;
  const OwnerBottomBar({super.key, required this.currentIndex});

  static const _items = [
    _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Home',
        route: AppRoutes.dashboard),
    _NavItem(
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics_rounded,
        label: 'Analytics',
        route: AppRoutes.analytics),
    _NavItem(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2_rounded,
        label: 'Products',
        route: AppRoutes.products),
    _NavItem(
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: 'Staff',
        route: AppRoutes.staff),
    _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Account',
        route: AppRoutes.account),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: _items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!selected) {
                      Navigator.of(context).pushReplacementNamed(item.route);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: selected
                              ? BoxDecoration(
                                  color:
                                      OwnerTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                )
                              : null,
                          child: Icon(
                            selected ? item.activeIcon : item.icon,
                            color: selected
                                ? OwnerTheme.primary
                                : OwnerTheme.textMuted,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w400,
                            color: selected
                                ? OwnerTheme.primary
                                : OwnerTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.route});
}
