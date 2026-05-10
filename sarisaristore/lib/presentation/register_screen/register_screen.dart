import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/api_client.dart';
import '../../services/auth_service.dart';
import 'package:dio/dio.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pageCtrl = PageController();

  // Page 1 — Store info
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();

  // Page 2 — Account
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  int _currentPage = 0;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  String? _errorMessage;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _pageCtrl.dispose();
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      if (_businessNameCtrl.text.trim().isEmpty) {
        _showError('Please enter your store name');
        return;
      }
      if (_ownerNameCtrl.text.trim().isEmpty) {
        _showError('Please enter the owner name');
        return;
      }
    }
    setState(() => _errorMessage = null);
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    setState(() => _errorMessage = null);
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showError(String msg) {
    setState(() => _errorMessage = msg);
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showError('Please accept the Terms of Service to continue');
      return;
    }
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await apiClient.post('/auth/register', data: {
        'businessName': _businessNameCtrl.text.trim(),
        'ownerName': _ownerNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });

      if (response.statusCode == 201) {
        final data = response.data;

        await AuthService().saveSession(
          token: data['accessToken'],
          refreshToken: data['refreshToken'],
          userName: data['user']['fullName'] ?? 'Store Owner',
          userEmail: data['user']['email'],
          userRole: data['user']['role'] ?? 'owner',
          tenantId: data['tenant']['id'],
          tenantName: data['tenant']['businessName'] ?? 'SariSari Pro Store',
        );

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.response != null && e.response?.data != null) {
          final data = e.response?.data;
          if (data['error'] != null) {
            _errorMessage = data['error'];
          } else if (data['errors'] != null && data['errors'].isNotEmpty) {
            _errorMessage = data['errors'][0]['msg'];
          } else {
            _errorMessage = 'Registration failed. Please try again.';
          }
        } else {
          _errorMessage =
              'Failed to connect. Please check your network connection.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                // ── Header ───────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(6.w, 3.h, 6.w, 0),
                  child: Row(
                    children: [
                      _BackButton(onTap: () {
                        if (_currentPage > 0) {
                          _prevPage();
                        } else {
                          Navigator.of(context).pop();
                        }
                      }),
                      const Spacer(),
                      Container(
                        width: 9.w,
                        height: 9.w,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(1.5.w),
                          child: CustomImageWidget(
                            imageUrl: 'assets/images/img_app_logo.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 2.h),

                // ── Title + Progress ──────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentPage == 0
                            ? 'Tell us about\nyour store 🏪'
                            : 'Create your\naccount 🔐',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        _currentPage == 0
                            ? 'Step 1 of 2 — Store information'
                            : 'Step 2 of 2 — Account credentials',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      _ProgressBar(currentPage: _currentPage, total: 2),
                    ],
                  ),
                ),

                SizedBox(height: 2.5.h),

                // ── Pages ────────────────────────────────
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _Page1(
                        businessNameCtrl: _businessNameCtrl,
                        ownerNameCtrl: _ownerNameCtrl,
                        errorMessage: _errorMessage,
                        onNext: _nextPage,
                      ),
                      _Page2(
                        formKey: _formKey,
                        emailCtrl: _emailCtrl,
                        passwordCtrl: _passwordCtrl,
                        confirmPasswordCtrl: _confirmPasswordCtrl,
                        obscurePassword: _obscurePassword,
                        obscureConfirm: _obscureConfirm,
                        agreedToTerms: _agreedToTerms,
                        isLoading: _isLoading,
                        errorMessage: _errorMessage,
                        onTogglePassword: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        onToggleConfirm: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        onToggleTerms: (v) =>
                            setState(() => _agreedToTerms = v ?? false),
                        onRegister: _handleRegister,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// Page 1: Store info
// ══════════════════════════════════════════

class _Page1 extends StatelessWidget {
  final TextEditingController businessNameCtrl;
  final TextEditingController ownerNameCtrl;
  final String? errorMessage;
  final VoidCallback onNext;

  const _Page1({
    required this.businessNameCtrl,
    required this.ownerNameCtrl,
    this.errorMessage,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: EdgeInsets.all(6.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorMessage != null) ...[
              _ErrorBannerLocal(message: errorMessage!),
              SizedBox(height: 2.h),
            ],

            _FieldLabelLocal(label: 'Store / Business Name'),
            SizedBox(height: 0.8.h),
            _StyledTF(
              controller: businessNameCtrl,
              hintText: "e.g. Maria's Sari-Sari Store",
              prefixIcon: Icons.store_outlined,
            ),

            SizedBox(height: 2.h),
            _FieldLabelLocal(label: 'Owner Full Name'),
            SizedBox(height: 0.8.h),
            _StyledTF(
              controller: ownerNameCtrl,
              hintText: 'e.g. Maria Santos',
              prefixIcon: Icons.person_outline_rounded,
            ),

            SizedBox(height: 3.h),

            // Highlight features
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD6D8FF)),
              ),
              child: Column(
                children: [
                  _FeatureRow(
                      icon: Icons.inventory_2_outlined,
                      text: 'Inventory & product tracking'),
                  _FeatureRow(
                      icon: Icons.receipt_long_outlined,
                      text: 'Point-of-sale & checkout'),
                  _FeatureRow(
                      icon: Icons.analytics_outlined,
                      text: 'Sales analytics & reports'),
                  _FeatureRow(
                      icon: Icons.trending_up_rounded,
                      text: 'AI-powered sales forecasting'),
                ],
              ),
            ),

            SizedBox(height: 3.h),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
            SizedBox(height: 1.h),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF3730A3),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// Page 2: Account credentials
// ══════════════════════════════════════════
class _Page2 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmPasswordCtrl;
  final bool obscurePassword;
  final bool obscureConfirm;
  final bool agreedToTerms;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final ValueChanged<bool?> onToggleTerms;
  final VoidCallback onRegister;

  const _Page2({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmPasswordCtrl,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.agreedToTerms,
    required this.isLoading,
    this.errorMessage,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onToggleTerms,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: EdgeInsets.all(6.w),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (errorMessage != null) ...[
                _ErrorBannerLocal(message: errorMessage!),
                SizedBox(height: 2.h),
              ],

              _FieldLabelLocal(label: 'Email Address'),
              SizedBox(height: 0.8.h),
              _StyledTF(
                controller: emailCtrl,
                hintText: 'you@yourstore.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),

              SizedBox(height: 2.h),
              _FieldLabelLocal(label: 'Password'),
              SizedBox(height: 0.8.h),
              _StyledTF(
                controller: passwordCtrl,
                hintText: 'Min. 8 characters',
                obscureText: obscurePassword,
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  onPressed: onTogglePassword,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 8)
                    return 'Password must be at least 8 characters';
                  return null;
                },
              ),

              SizedBox(height: 2.h),
              _FieldLabelLocal(label: 'Confirm Password'),
              SizedBox(height: 0.8.h),
              _StyledTF(
                controller: confirmPasswordCtrl,
                hintText: 'Re-enter your password',
                obscureText: obscureConfirm,
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  onPressed: onToggleConfirm,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return 'Please confirm your password';
                  return null;
                },
              ),

              SizedBox(height: 2.5.h),

              // Terms checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: agreedToTerms,
                    onChanged: onToggleTerms,
                    activeColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 11),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                          ),
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF4F46E5),
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF4F46E5),
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 2.5.h),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF4F46E5).withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          'Create My Store',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 1.h),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared local helpers ──────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int currentPage;
  final int total;
  const _ProgressBar({required this.currentPage, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i <= currentPage;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF4F46E5)
                  : Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

class _FieldLabelLocal extends StatelessWidget {
  final String label;
  const _FieldLabelLocal({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF475569),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _StyledTF extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _StyledTF({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle:
            GoogleFonts.inter(fontSize: 14, color: const Color(0xFFCBD5E1)),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF94A3B8), size: 20),
        suffixIcon: suffixIcon,
        fillColor: const Color(0xFFF8FAFC),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        errorStyle:
            GoogleFonts.inter(fontSize: 11, color: const Color(0xFFEF4444)),
      ),
    );
  }
}

class _ErrorBannerLocal extends StatelessWidget {
  final String message;
  const _ErrorBannerLocal({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
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
}
