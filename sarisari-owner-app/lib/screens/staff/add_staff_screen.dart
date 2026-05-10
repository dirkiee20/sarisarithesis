import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../core/api_client.dart';
import '../../theme/owner_theme.dart';

class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String _role = 'cashier';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  static const List<_StaffRoleOption> _roles = [
    _StaffRoleOption(
      value: 'cashier',
      title: 'Cashier',
      description: 'Can log in to the cashier app and record sales.',
      icon: Icons.point_of_sale_rounded,
    ),
    _StaffRoleOption(
      value: 'staff',
      title: 'Staff',
      description: 'General store helper account for day-to-day work.',
      icon: Icons.badge_outlined,
    ),
    _StaffRoleOption(
      value: 'manager',
      title: 'Manager',
      description: 'Can help owners manage store operations.',
      icon: Icons.manage_accounts_outlined,
    ),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await apiClient.post('/users/invite', data: {
        'fullName': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'role': _role,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFromDio(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to add staff. Please try again.');
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
        title: const Text('Add Staff'),
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
            const _CashierLoginInfoCard(),
            SizedBox(height: 2.h),
            _FormCard(
              children: [
                _Label('Full Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: 'Example: Maria Santos',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Full name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                _Label('Email Address'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: 'staff@yourstore.com',
                    icon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _Label('Temporary Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: 'At least 6 characters',
                    icon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _Label('Confirm Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordCtrl,
                  obscureText: _obscureConfirm,
                  decoration: _inputDecoration(
                    hint: 'Repeat temporary password',
                    icon: Icons.verified_user_outlined,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm password';
                    }
                    if (value != _passwordCtrl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Text(
              'Role',
              style: GoogleFonts.inter(
                color: OwnerTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 1.h),
            ..._roles.map(
              (role) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RoleCard(
                  role: role,
                  selected: _role == role.value,
                  onTap: () => setState(() => _role = role.value),
                ),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 1.h),
              _ErrorBanner(message: _error!),
            ],
            SizedBox(height: 2.h),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _saveStaff,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(
                  _loading ? 'Creating...' : 'Create Staff Account',
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

class _StaffRoleOption {
  const _StaffRoleOption({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String value;
  final String title;
  final String description;
  final IconData icon;
}

class _CashierLoginInfoCard extends StatelessWidget {
  const _CashierLoginInfoCard();

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
            child: const Icon(Icons.point_of_sale_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cashier app ready',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Staff created here can sign in to the cashier app using this email and temporary password.',
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final _StaffRoleOption role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? OwnerTheme.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? OwnerTheme.primary : OwnerTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: OwnerTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(role.icon, color: OwnerTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.title,
                    style: GoogleFonts.inter(
                      color: OwnerTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role.description,
                    style: GoogleFonts.inter(
                      color: OwnerTheme.textSecondary,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
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
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(color: OwnerTheme.textMuted, fontSize: 14),
    prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
    suffixIcon: suffix,
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
