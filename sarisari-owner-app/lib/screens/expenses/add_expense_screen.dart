import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../core/api_client.dart';
import '../../theme/owner_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String _category = 'Restocking';
  DateTime _expenseDate = DateTime.now();
  bool _loading = false;
  String? _error;

  static const List<String> _categories = [
    'Restocking',
    'Utilities',
    'Rent',
    'Staff Wages',
    'Transportation',
    'Packaging',
    'Maintenance',
    'Internet/Load',
    'Supplies',
    'Marketing',
    'General',
  ];

  static const List<_ExpenseTemplate> _templates = [
    _ExpenseTemplate(
      title: 'Inventory restock',
      category: 'Restocking',
      description: 'Products purchased for resale.',
      icon: Icons.inventory_2_outlined,
    ),
    _ExpenseTemplate(
      title: 'Electricity or water bill',
      category: 'Utilities',
      description: 'Monthly utility payment for store operations.',
      icon: Icons.bolt_outlined,
    ),
    _ExpenseTemplate(
      title: 'Store rent',
      category: 'Rent',
      description: 'Rental payment for the business space.',
      icon: Icons.storefront_outlined,
    ),
    _ExpenseTemplate(
      title: 'Staff salary or allowance',
      category: 'Staff Wages',
      description: 'Payment for cashier or helper work.',
      icon: Icons.groups_outlined,
    ),
    _ExpenseTemplate(
      title: 'Delivery or transport',
      category: 'Transportation',
      description: 'Fare, fuel, or delivery fee for supplies.',
      icon: Icons.local_shipping_outlined,
    ),
    _ExpenseTemplate(
      title: 'Plastic bags or packaging',
      category: 'Packaging',
      description: 'Packaging materials for customer purchases.',
      icon: Icons.shopping_bag_outlined,
    ),
    _ExpenseTemplate(
      title: 'Repairs or maintenance',
      category: 'Maintenance',
      description: 'Store equipment repair or upkeep.',
      icon: Icons.build_outlined,
    ),
    _ExpenseTemplate(
      title: 'Internet or mobile load',
      category: 'Internet/Load',
      description: 'Connectivity used for store transactions.',
      icon: Icons.wifi_outlined,
    ),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _applyTemplate(_ExpenseTemplate template) {
    setState(() {
      _titleCtrl.text = template.title;
      _descriptionCtrl.text = template.description;
      _category = template.category;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: OwnerTheme.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _expenseDate = picked);
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final amount = double.parse(_amountCtrl.text.replaceAll(',', '').trim());
      final description = _descriptionCtrl.text.trim();

      await apiClient.post('/expenses', data: {
        'title': _titleCtrl.text.trim(),
        'description': description.isEmpty ? null : description,
        'amount': amount,
        'category': _category,
        'expenseDate': DateFormat('yyyy-MM-dd').format(_expenseDate),
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFromDio(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to save expense. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    if (data is Map && data['errors'] is List && data['errors'].isNotEmpty) {
      final first = data['errors'].first;
      if (first is Map && first['msg'] != null) {
        return first['msg'].toString();
      }
    }
    return 'Failed to connect. Please check your network connection.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OwnerTheme.background,
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: OwnerTheme.border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          children: [
            _IntroCard(),
            SizedBox(height: 2.h),
            Text(
              'Common business expenses',
              style: GoogleFonts.inter(
                color: OwnerTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 1.h),
            ..._templates.map(
              (template) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TemplateCard(
                  template: template,
                  selected: _titleCtrl.text == template.title,
                  onTap: () => _applyTemplate(template),
                ),
              ),
            ),
            SizedBox(height: 1.h),
            _FormCard(
              children: [
                _Label('Expense Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: 'Example: Inventory restock',
                    icon: Icons.receipt_long_outlined,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Expense name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                _Label('Amount'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  decoration: _inputDecoration(
                    hint: '0.00',
                    icon: Icons.payments_outlined,
                    prefix: const Text('\u20B1 '),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                      value?.replaceAll(',', '').trim() ?? '',
                    );
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _Label('Category'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((category) {
                    final selected = category == _category;
                    return ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      selectedColor: OwnerTheme.primary.withValues(alpha: 0.12),
                      side: BorderSide(
                        color:
                            selected ? OwnerTheme.primary : OwnerTheme.border,
                      ),
                      labelStyle: GoogleFonts.inter(
                        color: selected
                            ? OwnerTheme.primary
                            : OwnerTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => setState(() => _category = category),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _Label('Expense Date'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: _inputDecoration(
                      hint: '',
                      icon: Icons.calendar_month_outlined,
                    ),
                    child: Text(
                      DateFormat('MMM d, yyyy').format(_expenseDate),
                      style: GoogleFonts.inter(
                        color: OwnerTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Label('Notes'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _inputDecoration(
                    hint: 'Supplier, receipt note, or reason for expense',
                    icon: Icons.notes_outlined,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              SizedBox(height: 2.h),
              _ErrorBanner(message: _error!),
            ],
            SizedBox(height: 2.h),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _saveExpense,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _loading ? 'Saving...' : 'Save Expense',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SizedBox(height: 3.h),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTemplate {
  const _ExpenseTemplate({
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
  });

  final String title;
  final String category;
  final String description;
  final IconData icon;
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: OwnerTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track operating costs',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Record restocking, rent, utilities, wages, packaging, and other daily business expenses.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final _ExpenseTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? OwnerTheme.primary : OwnerTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: OwnerTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(template.icon, color: OwnerTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    style: GoogleFonts.inter(
                      color: OwnerTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.category,
                    style: GoogleFonts.inter(
                      color: OwnerTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: selected ? OwnerTheme.primary : OwnerTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OwnerTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(
          color: OwnerTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      );
}

InputDecoration _inputDecoration({
  required String hint,
  required IconData icon,
  Widget? prefix,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(color: OwnerTheme.textMuted, fontSize: 14),
    prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
    prefix: prefix,
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: const Color(0xFFFECACA)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}
