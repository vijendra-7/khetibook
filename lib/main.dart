import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'providers/settings_provider.dart';
import 'providers/crop_price_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/global_options_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'providers/system_config_provider.dart';
import 'providers/faq_provider.dart';
import 'providers/price_override_provider.dart';
import 'providers/custom_options_provider.dart';
import 'providers/news_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/update_service.dart';
import 'services/firebase_init.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // START FIREBASE IN THE BACKGROUND (Do not await it)
  // This allows the Flutter Engine to instantly render the HomeScreen
  // using cached data while Firebase takes its ~500ms to boot silently.
  FirebaseInit.initialize();

  // Pre-load SharedPreferences synchronously so AuthProvider has the
  // logged-in state ready the exact millisecond the app builds.
  await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => CropPriceProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => GlobalOptionsProvider()),
        ChangeNotifierProvider(create: (_) => SystemConfigProvider()),
        ChangeNotifierProvider(create: (_) => FaqProvider()),
        ChangeNotifierProvider(create: (_) => PriceOverrideProvider()),
        ChangeNotifierProvider(create: (_) => CustomOptionsProvider()),
        ChangeNotifierProvider(create: (_) => NewsProvider()),
      ],
      child: const FarmerApp(),
    ),
  );
}

class FarmerApp extends StatefulWidget {
  const FarmerApp({super.key});

  @override
  State<FarmerApp> createState() => _FarmerAppState();
}

class _FarmerAppState extends State<FarmerApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<SettingsProvider>().themeMode;


    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KhetiBook',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: themeMode,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(),
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        child: _buildHome(context),
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // ── Fast path: returning user ─────────────────────────────────────────
    if (auth.isCachedLoggedIn) {
      FlutterNativeSplash.remove(); // Safe to remove, UI is ready
      return SystemConfigWrapper(
        key: const ValueKey('main'),
        child: BlockWrapper(
          child: (auth.user != null || auth.isCachedLoggedIn)
              ? const HomeScreen()
              : const LoginScreen(),
        ),
      );
    }

    // ── New / logged-out user path: show splash for branding ─────────────
    if (_showSplash || !auth.isInitialized) {
      FlutterNativeSplash.remove(); // Remove native so Dart splash plays
      return SplashScreen(
        key: const ValueKey('splash'),
        onFinish: () => setState(() => _showSplash = false),
        isCachedUser: false,
      );
    }

    // ── Splash done, waiting for Firebase stream (extremely rare) ─────────
    if (!auth.isAuthDetermined) {
      return Scaffold(
        key: const ValueKey('auth_loading'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2E7D32),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    // ── Stream resolved: show correct screen ─────────────────────────────
    FlutterNativeSplash.remove(); // UI is definitely ready here
    return SystemConfigWrapper(
      key: const ValueKey('main'),
      child: BlockWrapper(
        child: (auth.user != null || auth.isCachedLoggedIn)
            ? const HomeScreen()
            : const LoginScreen(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    const seedColor = Color(0xFF2E7D32);
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      // Dark mode: warm dark green surfaces
      // Light mode: soft cream-green tint (instead of plain white)
      surface: isDark ? const Color(0xFF0D1A0D) : const Color(0xFFF4FBF4),
      surfaceContainerLowest: isDark ? const Color(0xFF0A150A) : const Color(0xFFF0F9F0),
      surfaceContainerLow: isDark ? const Color(0xFF111E11) : const Color(0xFFECF7EC),
      surfaceContainer: isDark ? const Color(0xFF162116) : const Color(0xFFE8F5E9),
      surfaceContainerHigh: isDark ? const Color(0xFF1C2A1C) : const Color(0xFFE2F2E3),
      surfaceContainerHighest: isDark ? const Color(0xFF223322) : const Color(0xFFDAEEDB),
    );
    // Use the base TextTheme directly — avoids creating a throwaway ThemeData.
    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0A150A) : const Color(0xFFF0F9F0),
      textTheme: GoogleFonts.notoSansGujaratiTextTheme(baseTextTheme),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF0A150A) : colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 1,
        shadowColor: seedColor.withAlpha(isDark ? 0 : 40),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withAlpha(80),
        labelStyle: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withAlpha(160)),
        floatingLabelStyle: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
        prefixIconColor: colorScheme.onSurfaceVariant.withAlpha(200),
        suffixIconColor: colorScheme.onSurfaceVariant.withAlpha(200),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant.withAlpha(100)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class SystemConfigWrapper extends StatefulWidget {
  final Widget child;
  const SystemConfigWrapper({super.key, required this.child});

  @override
  State<SystemConfigWrapper> createState() => _SystemConfigWrapperState();
}

class _SystemConfigWrapperState extends State<SystemConfigWrapper> {
  bool _updateChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_updateChecked) {
      final config = context.read<SystemConfigProvider>();
      if (!config.isLoading) {
        if (config.checkOfficialUpdate) {
          UpdateService().checkForUpdate();
        }
        _updateChecked = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SystemConfigProvider>();
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isAdmin = user?.email == 'thevijendrachaudhary@gmail.com';

    final cs = Theme.of(context).colorScheme;

    // Force Update Check
    if (config.needsUpdate) {
      return Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.system_update_rounded, size: 32, color: cs.onPrimaryContainer),
                ),
                const SizedBox(height: 32),
                Text(
                  settings.isGujarati ? 'અપડેટ જરૂરી છે' : 'Update Required',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: cs.onSurface),
                ),
                const SizedBox(height: 16),
                Text(
                  settings.isGujarati 
                      ? 'એપ સંપૂર્ણ રીતે બરાબર છે, ચિંતા કરશો નહીં. 😊\n\nફક્ત નીચે આપેલા બટન પર ક્લિક કરો અને પછી Play Store માં "Update" બટન પર ક્લિક કરો. 😄'
                      : 'A new version of the app is available. Please update to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant, height: 1.5),
                ),
                if (config.updateImageUrl.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        config.updateImageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final uri = Uri.parse(config.updateUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      settings.isGujarati ? 'હવે અપડેટ કરો' : 'Update Now',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ), // Column
          ), // ConstrainedBox
        ); // return SingleChildScrollView
      }, // builder
    ), // LayoutBuilder
  ), // SafeArea
); // return Scaffold
    }

    // Maintenance Mode Check (Admin bypasses)
    if (config.isMaintenance && !isAdmin) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.construction_rounded, size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                Text(
                  settings.isGujarati ? 'મેન્ટેનન્સ' : 'Under Maintenance',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  settings.isGujarati ? config.maintenanceMsgGu : config.maintenanceMsgEn,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}


class BlockWrapper extends StatelessWidget {
  final Widget child;
  const BlockWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final settings = context.watch<SettingsProvider>();
    
    if (user == null || user.email == 'thevijendrachaudhary@gmail.com') return child;

    return FutureBuilder<void>(
      future: FirebaseInit.initialize(),
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done) {
          return child; // Render normal content silently while Firebase boots
        }
        
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users_profiles').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
        if (!snapshot.hasData) return child;
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data?['isBlocked'] == true) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block_rounded, size: 80, color: Colors.red),
                    const SizedBox(height: 24),
                    Text(
                      settings.isGujarati ? 'ખાતું પ્રતિબંધિત છે' : 'Account Blocked',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      settings.isGujarati 
                        ? 'તમારા ખાતા પર પ્રતિબંધ મૂકવામાં આવ્યો છે. વધુ માહિતી માટે એડમિનનો સંપર્ક કરો.' 
                        : 'Your account has been blocked. Please contact admin for more info.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () => context.read<AuthProvider>().signOut(),
                      child: Text(settings.isGujarati ? 'લોગ આઉટ' : 'Logout'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return child;
      },
    );
      },
    );
  }
}
