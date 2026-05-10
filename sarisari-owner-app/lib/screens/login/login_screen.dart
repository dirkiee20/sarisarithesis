import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';
import '../../theme/owner_theme.dart';
import '../../core/api_client.dart';
import 'package:dio/dio.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light),
    );
    _animCtrl = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await apiClient.post('/auth/login', data: {
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });

      if (response.statusCode == 200) {
        final data = response.data;

        // Ensure user is an owner
        if (data['user']['role'] != 'owner') {
          setState(() => _error = 'Please use the staff app to login.');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('owner_token', data['accessToken']);
        await prefs.setString('owner_refresh_token', data['refreshToken']);
        await prefs.setString(
            'owner_name', data['user']['fullName'] ?? 'Store Owner');
        await prefs.setString('owner_email', data['user']['email']);
        await prefs.setString(
            'owner_store', data['tenant']['businessName'] ?? 'Store');
        await prefs.setString(
            'owner_tier', data['tenant']['subscriptionTier'] ?? 'pro');

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.response != null &&
            e.response?.data != null &&
            e.response?.data['error'] != null) {
          _error = e.response?.data['error'];
        } else {
          _error = 'Failed to connect. Please check your network connection.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: OwnerTheme.headerGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Column(
                  children: [
                    SizedBox(height: 7.h),

                    // Logo
                    Container(
                      width: 17.w,
                      height: 17.w,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF4F46E5).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: const Icon(Icons.store_rounded,
                          color: Colors.white, size: 32),
                    ),
                    SizedBox(height: 2.h),
                    Text('SariSari Pro',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 0.5.h),
                    Text('Owner Dashboard',
                        style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13)),
                    SizedBox(height: 5.h),

                    // Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          )
                        ],
                      ),
                      padding: EdgeInsets.all(6.w),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome back',
                                style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: OwnerTheme.textPrimary)),
                            SizedBox(height: 0.5.h),
                            Text('Sign in to your owner account',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: OwnerTheme.textSecondary)),
                            SizedBox(height: 3.h),
                            if (_error != null) ...[
                              _ErrorBanner(message: _error!),
                              SizedBox(height: 2.h),
                            ],
                            _Label('Email Address'),
                            SizedBox(height: 0.8.h),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: OwnerTheme.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'you@yourstore.com',
                                hintStyle: GoogleFonts.inter(
                                    color: OwnerTheme.textMuted, fontSize: 14),
                                prefixIcon: const Icon(Icons.email_outlined,
                                    color: Color(0xFF94A3B8), size: 20),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email required';
                                }
                                if (!v.contains('@')) {
                                  return 'Enter valid email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 2.h),
                            _Label('Password'),
                            SizedBox(height: 0.8.h),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscure,
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: OwnerTheme.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                hintStyle: GoogleFonts.inter(
                                    color: OwnerTheme.textMuted, fontSize: 14),
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password required';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 3.h),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation(
                                                Colors.white)),
                                      )
                                    : Text('Sign In',
                                        style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700)),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Center(
                              child: TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.of(context)
                                        .pushNamed(AppRoutes.register),
                                child: Text(
                                  'Create an owner account',
                                  style: GoogleFonts.inter(
                                    color: OwnerTheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 4.h),
                    Text('SariSari Pro • Owner v1.0',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.3))),
                    SizedBox(height: 4.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: OwnerTheme.textSecondary,
          letterSpacing: 0.3));
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: const Color(0xFFFECACA)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFDC2626),
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      );
}
