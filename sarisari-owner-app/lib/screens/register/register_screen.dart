import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../core/api_client.dart';
import '../../routes/app_routes.dart';
import '../../theme/owner_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  int _step = 0;
  String _selectedTier = 'pro';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _paymentSimulated = false;
  bool _paymentLoading = false;
  bool _loading = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  static const List<_PlanOption> _plans = [
    _PlanOption(
      tier: 'free',
      title: 'Free',
      monthlyPrice: 0,
      description: 'Start with the basics while setting up your store.',
      icon: Icons.local_grocery_store_outlined,
      features: [
        '50 products',
        '1 owner account',
        '30-day reports',
      ],
    ),
    _PlanOption(
      tier: 'pro',
      title: 'Pro',
      monthlyPrice: 299,
      description: 'Best for active sari-sari stores using AI insights.',
      icon: Icons.auto_awesome_rounded,
      highlighted: true,
      features: [
        'Unlimited products',
        'Up to 5 users',
        'AI sales insights',
      ],
    ),
    _PlanOption(
      tier: 'enterprise',
      title: 'Enterprise',
      monthlyPrice: 999,
      description: 'For larger teams that need priority support.',
      icon: Icons.workspace_premium_outlined,
      features: [
        'Unlimited everything',
        'Priority support',
        'Advanced controls',
      ],
    ),
  ];

  _PlanOption get _selectedPlan =>
      _plans.firstWhere((plan) => plan.tier == _selectedTier);

  String get _simulationReference =>
      'SIM-${_selectedTier.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}';

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
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0 && !_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _step = (_step + 1).clamp(0, 2);
    });
  }

  void _previousStep() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _error = null;
      _step = (_step - 1).clamp(0, 2);
    });
  }

  void _selectPlan(String tier) {
    setState(() {
      _selectedTier = tier;
      _paymentSimulated = tier == 'free';
      _error = null;
    });
  }

  Future<void> _simulatePayment() async {
    setState(() {
      _paymentLoading = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() {
      _paymentLoading = false;
      _paymentSimulated = true;
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _step = 0);
      return;
    }

    if (_selectedTier != 'free' && !_paymentSimulated) {
      setState(() => _error = 'Please run the simulated payment first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await apiClient.post('/auth/register', data: {
        'businessName': _businessNameCtrl.text.trim(),
        'ownerName': _ownerNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'address':
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'subscriptionTier': _selectedTier,
        'paymentSimulation': {
          'enabled': true,
          'status': _selectedTier == 'free' ? 'not_required' : 'approved',
          'reference': _simulationReference,
        },
      });

      if (response.statusCode == 201) {
        final data = response.data;
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('owner_token', data['accessToken']);
        await prefs.setString('owner_refresh_token', data['refreshToken']);
        await prefs.setString(
          'owner_name',
          data['user']['fullName'] ?? _ownerNameCtrl.text.trim(),
        );
        await prefs.setString('owner_email', data['user']['email']);
        await prefs.setString(
          'owner_store',
          data['tenant']['businessName'] ?? _businessNameCtrl.text.trim(),
        );
        await prefs.setString(
          'owner_tier',
          data['tenant']['subscriptionTier'] ?? _selectedTier,
        );

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFromDio(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'An unexpected error occurred.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
                    SizedBox(height: 3.h),
                    _Header(onBack: _previousStep),
                    SizedBox(height: 3.h),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 38,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(5.5.w),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StepIndicator(currentStep: _step),
                            SizedBox(height: 2.8.h),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _buildStep(),
                            ),
                            if (_error != null) ...[
                              SizedBox(height: 2.h),
                              _ErrorBanner(message: _error!),
                            ],
                            SizedBox(height: 3.h),
                            _ActionRow(
                              step: _step,
                              loading: _loading,
                              paymentReady:
                                  _selectedTier == 'free' || _paymentSimulated,
                              onBack: _previousStep,
                              onNext: _nextStep,
                              onRegister: _register,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 2.5.h),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context)
                              .pushReplacementNamed(AppRoutes.login),
                      child: Text(
                        'Already have an account? Sign in',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 3.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _BusinessDetailsStep(
          key: const ValueKey('business-details'),
          businessNameCtrl: _businessNameCtrl,
          ownerNameCtrl: _ownerNameCtrl,
          emailCtrl: _emailCtrl,
          phoneCtrl: _phoneCtrl,
          addressCtrl: _addressCtrl,
          passwordCtrl: _passwordCtrl,
          confirmPasswordCtrl: _confirmPasswordCtrl,
          obscurePassword: _obscurePassword,
          obscureConfirm: _obscureConfirm,
          onTogglePassword: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          onToggleConfirm: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
        );
      case 1:
        return _PlanStep(
          key: const ValueKey('plan-selection'),
          plans: _plans,
          selectedTier: _selectedTier,
          onSelected: _selectPlan,
        );
      default:
        return _SimulationStep(
          key: const ValueKey('payment-simulation'),
          selectedPlan: _selectedPlan,
          simulated: _selectedTier == 'free' || _paymentSimulated,
          loading: _paymentLoading,
          onSimulate: _simulatePayment,
        );
    }
  }
}

class _PlanOption {
  const _PlanOption({
    required this.tier,
    required this.title,
    required this.monthlyPrice,
    required this.description,
    required this.features,
    required this.icon,
    this.highlighted = false,
  });

  final String tier;
  final String title;
  final int monthlyPrice;
  final String description;
  final List<String> features;
  final IconData icon;
  final bool highlighted;

  String get priceLabel => monthlyPrice == 0
      ? 'Free'
      : '${String.fromCharCode(0x20B1)}$monthlyPrice/month';
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: OwnerTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: OwnerTheme.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.store_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Owner Account',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a plan now. Payment is simulated for thesis testing.',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Store', 'Plan', 'Simulation'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color:
                      active ? OwnerTheme.primary : OwnerTheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.inter(
                      color: active ? Colors.white : OwnerTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  labels[index],
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color:
                        active ? OwnerTheme.textPrimary : OwnerTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (index != labels.length - 1)
                Container(
                  width: 18,
                  height: 2,
                  color: index < currentStep
                      ? OwnerTheme.primary
                      : OwnerTheme.border,
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _BusinessDetailsStep extends StatelessWidget {
  const _BusinessDetailsStep({
    super.key,
    required this.businessNameCtrl,
    required this.ownerNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.passwordCtrl,
    required this.confirmPasswordCtrl,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onTogglePassword,
    required this.onToggleConfirm,
  });

  final TextEditingController businessNameCtrl;
  final TextEditingController ownerNameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmPasswordCtrl;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Store details',
          subtitle: 'This creates the tenant and owner login account.',
        ),
        SizedBox(height: 2.2.h),
        _Label('Business Name'),
        SizedBox(height: 0.7.h),
        TextFormField(
          controller: businessNameCtrl,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            hint: 'Juan Sari-Sari Store',
            icon: Icons.storefront_outlined,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Business name required'
              : null,
        ),
        SizedBox(height: 1.8.h),
        _Label('Owner Name'),
        SizedBox(height: 0.7.h),
        TextFormField(
          controller: ownerNameCtrl,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            hint: 'Juan Dela Cruz',
            icon: Icons.person_outline_rounded,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Owner name required'
              : null,
        ),
        SizedBox(height: 1.8.h),
        _Label('Email Address'),
        SizedBox(height: 0.7.h),
        TextFormField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            hint: 'owner@store.com',
            icon: Icons.email_outlined,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Email required';
            }
            if (!value.contains('@')) return 'Enter valid email';
            return null;
          },
        ),
        SizedBox(height: 1.8.h),
        _Label('Phone Number'),
        SizedBox(height: 0.7.h),
        TextFormField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            hint: 'Optional',
            icon: Icons.phone_outlined,
          ),
        ),
        SizedBox(height: 1.8.h),
        _Label('Store Address'),
        SizedBox(height: 0.7.h),
        TextFormField(
          controller: addressCtrl,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            hint: 'Optional',
            icon: Icons.location_on_outlined,
          ),
        ),
        SizedBox(height: 1.8.h),
        _Label('Password'),
        SizedBox(height: 0.7.h),
        TextFormField(
          controller: passwordCtrl,
          obscureText: obscurePassword,
          decoration: _inputDecoration(
            hint: 'At least 6 characters',
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: onTogglePassword,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Password required';
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        SizedBox(height: 1.8.h),
        _Label('Confirm Password'),
        SizedBox(height: 0.7.h),
        TextFormField(
          controller: confirmPasswordCtrl,
          obscureText: obscureConfirm,
          decoration: _inputDecoration(
            hint: 'Repeat password',
            icon: Icons.verified_user_outlined,
            suffix: IconButton(
              icon: Icon(
                obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: onToggleConfirm,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm password';
            }
            if (value != passwordCtrl.text) return 'Passwords do not match';
            return null;
          },
        ),
      ],
    );
  }
}

class _PlanStep extends StatelessWidget {
  const _PlanStep({
    super.key,
    required this.plans,
    required this.selectedTier,
    required this.onSelected,
  });

  final List<_PlanOption> plans;
  final String selectedTier;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Choose your subscription',
          subtitle:
              'This is only a thesis simulation. No real payment happens.',
        ),
        SizedBox(height: 2.h),
        ...plans.map(
          (plan) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlanCard(
              plan: plan,
              selected: selectedTier == plan.tier,
              onTap: () => onSelected(plan.tier),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final _PlanOption plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? OwnerTheme.primary.withValues(alpha: 0.07)
              : OwnerTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? OwnerTheme.primary : OwnerTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? OwnerTheme.primary.withValues(alpha: 0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(plan.icon, color: OwnerTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.title,
                              style: GoogleFonts.inter(
                                color: OwnerTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (plan.highlighted) ...[
                            const SizedBox(width: 8),
                            _MiniBadge(label: 'Recommended'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        plan.priceLabel,
                        style: GoogleFonts.inter(
                          color: OwnerTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
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
            const SizedBox(height: 12),
            Text(
              plan.description,
              style: GoogleFonts.inter(
                color: OwnerTheme.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: plan.features
                  .map((feature) => _FeatureChip(label: feature))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimulationStep extends StatelessWidget {
  const _SimulationStep({
    super.key,
    required this.selectedPlan,
    required this.simulated,
    required this.loading,
    required this.onSimulate,
  });

  final _PlanOption selectedPlan;
  final bool simulated;
  final bool loading;
  final VoidCallback onSimulate;

  @override
  Widget build(BuildContext context) {
    final isFree = selectedPlan.tier == 'free';
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Payment simulation',
          subtitle: isFree
              ? 'Free plan does not need payment. You can register now.'
              : 'This confirms the selected plan without charging real money.',
        ),
        SizedBox(height: 2.h),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OwnerTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: OwnerTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isFree
                          ? Icons.card_giftcard_rounded
                          : Icons.credit_score_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedPlan.title,
                          style: GoogleFonts.inter(
                            color: OwnerTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          selectedPlan.priceLabel,
                          style: GoogleFonts.inter(
                            color: OwnerTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _MiniBadge(label: simulated ? 'Ready' : 'Demo'),
                ],
              ),
              const SizedBox(height: 16),
              _PaymentLine(
                label: 'Gateway',
                value: isFree ? 'Not required' : 'SariSari Demo Pay',
              ),
              _PaymentLine(
                label: 'Mode',
                value: isFree ? 'Free activation' : 'Simulation only',
              ),
              _PaymentLine(
                label: 'Status',
                value: simulated ? 'Approved' : 'Pending simulation',
                success: simulated,
              ),
            ],
          ),
        ),
        if (!isFree) ...[
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: loading || simulated ? null : onSimulate,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      simulated
                          ? Icons.check_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                    ),
              label: Text(
                simulated
                    ? 'Payment Simulation Approved'
                    : 'Run Payment Simulation',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.step,
    required this.loading,
    required this.paymentReady,
    required this.onBack,
    required this.onNext,
    required this.onRegister,
  });

  final int step;
  final bool loading;
  final bool paymentReady;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (step > 0)
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: loading ? null : onBack,
                child: Text(
                  'Back',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        if (step > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: loading
                  ? null
                  : step == 2
                      ? onRegister
                      : onNext,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      step == 2
                          ? paymentReady
                              ? 'Create Account'
                              : 'Create Account'
                          : 'Continue',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: OwnerTheme.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: OwnerTheme.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
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
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: OwnerTheme.textSecondary,
          letterSpacing: 0.3,
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

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OwnerTheme.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: OwnerTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: OwnerTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: OwnerTheme.accent,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentLine extends StatelessWidget {
  const _PaymentLine({
    required this.label,
    required this.value,
    this.success = false,
  });

  final String label;
  final String value;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: OwnerTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: success ? OwnerTheme.accent : OwnerTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
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
