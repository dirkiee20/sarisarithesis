import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';

/// Shown once after a successful registration.
/// Gives the user a guided walkthrough of the app's key features.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const _pages = [
    _OnboardPage(
      emoji: '🏪',
      title: 'Manage Your\nInventory',
      subtitle:
          'Add products, track stock levels, and get low-stock alerts before you run out.',
      color1: Color(0xFF4F46E5),
      color2: Color(0xFF7C3AED),
    ),
    _OnboardPage(
      emoji: '🧾',
      title: 'Fast &\nEasy Checkout',
      subtitle:
          'Process sales quickly with barcode scanning, cart management, and automatic change calculation.',
      color1: Color(0xFF0EA5E9),
      color2: Color(0xFF0284C7),
    ),
    _OnboardPage(
      emoji: '📊',
      title: 'Know Your\nNumbers',
      subtitle:
          'Track revenue, profit, and expenses in real-time with beautiful charts and analytics.',
      color1: Color(0xFF10B981),
      color2: Color(0xFF059669),
    ),
    _OnboardPage(
      emoji: '🤖',
      title: 'AI-Powered\nInsights',
      subtitle:
          'Get smart sales forecasts and restocking suggestions powered by machine learning.',
      color1: Color(0xFFF59E0B),
      color2: Color(0xFFD97706),
    ),
  ];

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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToApp();
    }
  }

  void _goToApp() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.productsTab);
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [page.color1, page.color2],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                // ── Skip button ──────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(6.w, 2.h, 6.w, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Step counter
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${_currentPage + 1} of ${_pages.length}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_currentPage < _pages.length - 1)
                        TextButton(
                          onPressed: _goToApp,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 60),
                    ],
                  ),
                ),

                // ── Content pages ────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _OnboardingPageView(page: _pages[index]);
                    },
                  ),
                ),

                // ── Bottom controls ──────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(6.w, 0, 6.w, 5.h),
                  child: Column(
                    children: [
                      // Dot indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _currentPage ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          );
                        }),
                      ),

                      SizedBox(height: 4.h),

                      // CTA button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: page.color1,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1
                                    ? "Let's Get Started!"
                                    : 'Next',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: page.color1,
                                ),
                              ),
                              if (_currentPage < _pages.length - 1) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: page.color1,
                                ),
                              ],
                            ],
                          ),
                        ),
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

// ─── Data model ───────────────────────────────────────
class _OnboardPage {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color1;
  final Color color2;

  const _OnboardPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color1,
    required this.color2,
  });
}

// ─── Page content widget ──────────────────────────────
class _OnboardingPageView extends StatelessWidget {
  final _OnboardPage page;
  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big emoji in a frosted glass container
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                page.emoji,
                style: TextStyle(fontSize: 22.w),
              ),
            ),
          ),

          SizedBox(height: 5.h),

          Text(
            page.title,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 2.h),

          Text(
            page.subtitle,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
