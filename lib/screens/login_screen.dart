import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLanguageExpanded = false;
  Timer? _languageTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _languageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final gu = settingsProvider.isGujarati;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Dynamic color palette
    final Color bg0 = isDark ? const Color(0xFF0F1223) : const Color(0xFFF8F9FF);
    final Color bg1 = isDark ? const Color(0xFF1B2144) : const Color(0xFFE8EAF6);
    final Color purpleStart = isDark ? const Color(0xFFA184FF) : const Color(0xFF7C4DFF);
    final Color purpleEnd = isDark ? const Color(0xFF7045FF) : const Color(0xFF6200EA);
    final Color textColor = isDark ? Colors.white : const Color(0xFF1B2144);
    final Color subtitleColor = isDark ? Colors.white.withAlpha(150) : const Color(0xFF5C6BC0);

    return Scaffold(
      backgroundColor: bg0,
      body: Stack(
        children: [
          // Dynamic Gradient Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bg0, bg1],
              ),
            ),
          ),
          
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Language Toggle
                            Align(
                              alignment: Alignment.topRight,
                              child: GestureDetector(
                                onTap: () {
                                  settingsProvider.toggleLanguage();
                                  setState(() {
                                    _isLanguageExpanded = true;
                                  });
                                  _languageTimer?.cancel();
                                  _languageTimer = Timer(const Duration(seconds: 2), () {
                                    if (mounted) {
                                      setState(() {
                                        _isLanguageExpanded = false;
                                      });
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: _isLanguageExpanded ? 16 : 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.language_rounded, 
                                        color: isDark ? Colors.white70 : Colors.black54,
                                        size: 20,
                                      ),
                                      AnimatedSize(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOutCubic,
                                        child: _isLanguageExpanded
                                            ? Padding(
                                                padding: const EdgeInsets.only(left: 8.0),
                                                child: Text(
                                                  gu ? 'ગુજરાતી' : 'English',
                                                  style: TextStyle(
                                                    color: isDark ? Colors.white70 : Colors.black87,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Modern Logo Card
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(150),
                                        borderRadius: BorderRadius.circular(40),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(isDark ? 30 : 15),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Transform.scale(
                                        scale: 1.5,
                                        child: Image.asset(
                                          'assets/images/logo_padded.webp',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    Text(
                                      gu ? 'ખેતીબુક' : 'KhetiBook',
                                      style: theme.textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      gu ? 'તમારા ખેતીના હિસાબને સુરક્ષિત બનાવો' : 'Secure your farming business',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 15,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const Spacer(),

                            // Feature List Section
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Column(
                                  children: [
                                    _buildFeatureItem(
                                      icon: Icons.description_rounded,
                                      title: gu ? '૭/૧૨ અને ૮-અ ના ઉતારા' : '7/12 & 8-A Records',
                                      subtitle: gu ? 'તમારા મોબાઈલમાં સરળતાથી મેળવો' : 'Easily view land records on mobile',
                                      color: Colors.blueAccent,
                                      textColor: textColor,
                                      subtitleColor: subtitleColor,
                                    ),
                                    _buildFeatureItem(
                                      icon: Icons.analytics_rounded,
                                      title: gu ? 'આવક-ખર્ચનું વિગતવાર વિશ્લેષણ' : 'Detailed Expense Analysis',
                                      subtitle: gu ? 'તમારા નફા-નુકસાનને ટ્રેક કરો' : 'Track your profit and loss easily',
                                      color: Colors.orangeAccent,
                                      textColor: textColor,
                                      subtitleColor: subtitleColor,
                                    ),
                                    _buildFeatureItem(
                                      icon: Icons.trending_up_rounded,
                                      title: gu ? 'બજાર ભાવ અને લેટેસ્ટ અપડેટ' : 'Market Rates & Updates',
                                      subtitle: gu ? 'રોજિંદા ખેતીના બજાર ભાવ જાણો' : 'Get daily APMC mandi rates',
                                      color: Colors.greenAccent,
                                      textColor: textColor,
                                      subtitleColor: subtitleColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const Spacer(),

                            // Sign In Button (Apple on iOS, Google on Android)
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (authProvider.isLoading)
                                    CircularProgressIndicator(color: purpleStart)
                                  else ...[  
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 1.0, end: 1.02),
                                      duration: const Duration(milliseconds: 1500),
                                      curve: Curves.easeInOutSine,
                                      builder: (context, scale, child) {
                                        return Transform.scale(
                                          scale: scale,
                                          child: child,
                                        );
                                      },
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 60,
                                        child: Platform.isIOS
                                            ? _buildAppleButton(context, authProvider, gu, isDark, cs)
                                            : _buildGoogleButton(context, authProvider, gu, isDark, cs),
                                      ),
                                    ),
                                    // Anonymous option — iOS only
                                    if (Platform.isIOS) ...[  
                                      const SizedBox(height: 12),
                                      _buildAnonymousButton(context, authProvider, gu, isDark),
                                    ],
                                  ],
                                  const SizedBox(height: 16),
                                  Text(
                                    gu ? 'એપમાં પ્રવેશ કરવા માટે ઉપરના બટન પર ક્લિક કરો' : 'Click the button above to enter the app',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black54,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    Platform.isIOS
                                        ? (gu ? 'તમારો ડેટા તમારા Apple ID સાથે સુરક્ષિત રહેશે' : 'Your data is saved securely to your Apple ID')
                                        : (gu ? 'તમારો ડેટા તમારા Google એકાઉન્ટ સાથે સુરક્ષિત રહેશે' : 'Your data is saved securely to your Google account'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white.withAlpha(80) : Colors.black38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnonymousButton(BuildContext context, AuthProvider authProvider, bool gu, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: () async {
          // Warn user that data won't be backed up
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(gu ? 'એકાઉન્ટ વિના ચાલુ રાખો?' : 'Continue without account?'),
              content: Text(
                gu
                    ? 'તમારો ડેટા ફક્ત આ ફોનમાં સેવ થશે. ફોન બદલ્યા પછી ડેટા ગુમ થઈ શકે છે.'
                    : 'Your data will only be saved on this phone. If you change your phone, data may be lost.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(gu ? 'રદ કરો' : 'Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(gu ? 'ચાલુ રાખો' : 'Continue'),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          final success = await authProvider.signInAnonymously();
          if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(gu ? 'ભૂલ આવી' : 'Sign in failed'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white60 : Colors.black45,
          side: BorderSide(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: isDark ? Colors.white54 : Colors.black38,
            ),
            const SizedBox(width: 10),
            Text(
              gu ? 'છોડો' : 'Skip',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleButton(BuildContext context, AuthProvider authProvider, bool gu, bool isDark, ColorScheme cs) {
    return ElevatedButton(
      onPressed: () async {
        final success = await authProvider.signInWithApple();
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(gu ? 'ભૂલ આવી' : 'Sign in failed'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? Colors.white : Colors.black,
        foregroundColor: isDark ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: isDark ? 8 : 4,
        shadowColor: Colors.black.withAlpha(isDark ? 50 : 40),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.apple,
            size: 28,
            color: isDark ? Colors.black : Colors.white,
          ),
          const SizedBox(width: 12),
          Text(
            gu ? 'Apple સાથે શરૂ કરો' : 'Continue with Apple',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton(BuildContext context, AuthProvider authProvider, bool gu, bool isDark, ColorScheme cs) {
    return ElevatedButton(
      onPressed: () async {
        final success = await authProvider.signInWithGoogle();
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(gu ? 'ભૂલ આવી' : 'Sign in failed'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark ? BorderSide.none : BorderSide(color: cs.outlineVariant.withAlpha(50)),
        ),
        elevation: isDark ? 8 : 4,
        shadowColor: Colors.black.withAlpha(isDark ? 50 : 30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'G',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.blue.shade700,
              fontFamily: 'sans-serif',
            ),
          ),
          const SizedBox(width: 16),
          Text(
            gu ? 'Google સાથે શરૂ કરો' : 'Continue with Google',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(40),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
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
