import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../utils/panchang_helper.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  /// When true, the splash plays a short 600ms animation instead of the full
  /// 1500ms one. Pass true for returning users who already have a cached session.
  final bool isCachedUser;

  const SplashScreen({
    super.key,
    required this.onFinish,
    this.isCachedUser = false,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();

    // Returning users already have auth cached — play a shorter animation
    // so they reach HomeScreen faster. New users get the full welcome animation.
    final isFastMode = widget.isCachedUser;
    final totalDuration = isFastMode
        ? const Duration(milliseconds: 600)
        : const Duration(milliseconds: 1500);

    _controller = AnimationController(
      vsync: this,
      duration: totalDuration,
    );

    // Background load data during splash animation
    PanchangHelper.loadData();

    // 0.0s - 1.0s: Logo scaling and fade in
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // 0.8s - 1.8s: Title sliding up and fade in
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
      ),
    );

    // 1.5s - 2.5s: Tagline fade in
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.9, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      if (mounted) widget.onFinish();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gu = settings.isGujarati;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A150A) : const Color(0xFFF0F9F0),
      body: Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.webp',
                      width: 80,
                      height: 80,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              FadeTransition(
                opacity: _titleOpacity,
                child: SlideTransition(
                  position: _titleSlide,
                  child: Text(
                    gu ? 'ખેતીબુક' : 'KhetiBook',
                    style: GoogleFonts.notoSansGujarati(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2E7D32),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              FadeTransition(
                opacity: _taglineOpacity,
                child: Column(
                  children: [
                    Text(
                      gu ? 'તમારો ડિજિટલ ખેતી ચોપડો' : 'Your Digital Farming Register',
                      style: GoogleFonts.notoSansGujarati(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const _BouncingDots(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }
  }

  class _BouncingDots extends StatefulWidget {
    const _BouncingDots();

    @override
    State<_BouncingDots> createState() => _BouncingDotsState();
  }

  class _BouncingDotsState extends State<_BouncingDots> with SingleTickerProviderStateMixin {
    late AnimationController _controller;

    @override
    void initState() {
      super.initState();
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      )..repeat();
    }

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return _BouncingDot(
            controller: _controller,
            index: index,
          );
        }),
      );
    }
  }

  class _BouncingDot extends StatelessWidget {
    final AnimationController controller;
    final int index;

    const _BouncingDot({required this.controller, required this.index});

    @override
    Widget build(BuildContext context) {
      final animation = CurvedAnimation(
        parent: controller,
        curve: Interval(
          index * 0.2,
          0.6 + (index * 0.2),
          curve: Curves.easeInOut,
        ),
      );

      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          // Cleaner stagger logic: each dot bounces on a parabolic arc
          double dy = 0;
          final t = controller.value;
          final shift = index * 0.2;
          final localT = (t - shift) % 1.0;
          if (localT < 0.5) {
            dy = -10 * (1 - (2 * localT - 1) * (2 * localT - 1)); // Parabolic bounce
          } else {
            dy = 0;
          }

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            transform: Matrix4.translationValues(0, dy, 0),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              shape: BoxShape.circle,
            ),
          );
        },
      );
    }
  }
