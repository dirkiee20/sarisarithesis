import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/owner_data_service.dart';
import '../../theme/owner_theme.dart';
import '../../widgets/owner_assistant_bubble.dart';
import '../../widgets/owner_bottom_bar.dart';
import 'product_details_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _search = '';
  String _filter = 'All';
  final _filters = ['All', 'In Stock', 'Low Stock', 'Out of Stock'];
  final _dataService = const OwnerDataService();
  List<Map<String, dynamic>> _products = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final products = await _dataService.loadProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load product summaries.';
        _loading = false;
      });
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'In Stock':
        return OwnerTheme.accent;
      case 'Low Stock':
        return OwnerTheme.warning;
      default:
        return OwnerTheme.error;
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _products.where((p) {
      final matchSearch = _search.isEmpty ||
          (p['name'] as String).toLowerCase().contains(_search.toLowerCase());
      final matchFilter = _filter == 'All' || p['status'] == _filter;
      return matchSearch && matchFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OwnerTheme.background,
      appBar: AppBar(
        title: Text('Products (${_products.length})'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: OwnerTheme.border),
        ),
      ),
      body: Column(
        children: [
          // Search + filter
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(4.w, 12, 4.w, 0),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: GoogleFonts.inter(
                        color: OwnerTheme.textMuted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF94A3B8), size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((f) {
                      final sel = f == _filter;
                      return GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8, bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? OwnerTheme.primary
                                : OwnerTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(f,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? Colors.white
                                      : OwnerTheme.textSecondary)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Product list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _MessageState(message: _error!, onRetry: _loadProducts)
                    : _filtered.isEmpty
                        ? const _MessageState(
                            message:
                                'No product summaries found. Sync from the cashier app first.',
                          )
                        : ListView.builder(
              padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 12.h),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final p = _filtered[i];
                final statusColor = _statusColor(p['status'] as String);
                return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailsScreen(product: p),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: OwnerTheme.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: OwnerTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory_2_outlined,
                                color: OwnerTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['name'] as String,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: OwnerTheme.textPrimary)),
                                Text(p['category'] as String,
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: OwnerTheme.textMuted)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(p['price'] as String,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: OwnerTheme.textPrimary)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text('Stock: ${p['stock']}',
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ));
              },
            ),
          ),
        ],
      ),
      floatingActionButton: const OwnerAssistantBubble(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const OwnerBottomBar(currentIndex: 2),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _MessageState({
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

