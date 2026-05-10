import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/owner_theme.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    if (s == 'In Stock') return OwnerTheme.accent;
    if (s == 'Low Stock') return OwnerTheme.warning;
    return OwnerTheme.error;
  }

  void _showActionSnackbar(String action) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$action functionality coming soon!'),
      backgroundColor: OwnerTheme.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(widget.product['status'] as String);
    final stock = widget.product['stock'] as int;

    return Scaffold(
      backgroundColor: OwnerTheme.background,
      appBar: AppBar(
        title: Text(
          'Product Details',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: OwnerTheme.textPrimary,
            onPressed: () => _showActionSnackbar('Edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: OwnerTheme.error,
            onPressed: () => _showActionSnackbar('Delete'),
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 3.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero Card ─────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)], // Indigo gradients
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          widget.product['name'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          widget.product['category'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 4.h),

                  // ── Stats Section ─────────────────────────────
                  Row(
                    children: [
                      // Price Stat
                      Expanded(
                        child: _StatCard(
                          icon: Icons.sell_outlined,
                          title: 'Selling Price',
                          value: widget.product['price'] as String,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      // Stock Stat
                      Expanded(
                        child: _StatCard(
                          icon: Icons.inventory_outlined,
                          title: 'Current Stock',
                          value: stock.toString(),
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 4.h),

                  // ── Status Banner ──────────────────────────────
                  Text(
                    'Inventory Status',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: OwnerTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 1.5.h),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OwnerTheme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_outline,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.product['status'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                stock == 0
                                    ? 'Needs immediate restock.'
                                    : (stock < 10
                                        ? 'Running low, recommend restocking.'
                                        : 'Sufficient stock available.'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: OwnerTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 4.h),

                  // ── Action Buttons ──────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _showActionSnackbar('Adjust Stock'),
                      icon: const Icon(Icons.add_shopping_cart, size: 20),
                      label: Text(
                        'Adjust Stock Level',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OwnerTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _showActionSnackbar('View Analytics'),
                      icon: const Icon(Icons.bar_chart_rounded, size: 20),
                      label: Text(
                        'View Sales Analytics',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OwnerTheme.primary,
                        side: BorderSide(color: OwnerTheme.primary.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 5.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OwnerTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(height: 1.5.h),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: OwnerTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: OwnerTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
