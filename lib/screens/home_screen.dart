import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import 'crop_price_screen.dart';
import 'accounting_screen.dart';
import 'admin/admin_panel_screen.dart';
import 'admin/admin_user_list_screen.dart';
import 'news_screen.dart';
import 'land_records_native_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.select<SettingsProvider, bool>((p) => p.isGujarati);
    final user = context.select<AuthProvider, dynamic>((p) => p.user);
    final isAdmin = user?.email == 'thevijendrachaudhary@gmail.com';
    final isAdminMode = isAdmin && context.select<SettingsProvider, bool>((p) => p.isAdminMode);

    final List<Widget> screens;
    if (isAdminMode) {
      screens = [
        const AccountingScreen(),
        const AdminPanelScreen(),
        const LandRecordsNativeScreen(),
        const CropPriceScreen(),
      ];
    } else {
      screens = [
        const CropPriceScreen(),
        const AccountingScreen(),
        const LandRecordsNativeScreen(),
        NewsScreen(isActive: _selectedIndex == 3),
      ];
    }

    // Clamp index to avoid issues when switching modes
    final effectiveIndex = _selectedIndex >= screens.length ? 0 : _selectedIndex;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: IndexedStack(
        index: effectiveIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border(
            top: BorderSide(
              color: Colors.black.withAlpha(20),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 15,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: effectiveIndex,
          elevation: 0,
          backgroundColor: cs.surfaceContainerLow,
          indicatorColor: const Color(0xFFD8F3DC),
          indicatorShape: const StadiumBorder(),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 80,
          animationDuration: const Duration(milliseconds: 250),
          onDestinationSelected: (int index) {
            if (_selectedIndex != index) {
              HapticFeedback.lightImpact();
              setState(() => _selectedIndex = index);
            }
          },
          destinations: isAdminMode ? [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Transform.scale(
                scale: 1.15,
                child: const Icon(Icons.home_rounded, color: Color(0xFF1B5E20), size: 28),
              ),
              label: gu ? 'ડેશબોર્ડ' : 'Dashboard',
            ),
            NavigationDestination(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Transform.scale(
                scale: 1.15,
                child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF1B5E20), size: 28),
              ),
              label: gu ? 'એડમિન' : 'Admin',
            ),
            NavigationDestination(
              icon: const Icon(Icons.article_outlined),
              selectedIcon: Transform.scale(
                scale: 1.15,
                child: const Icon(Icons.article_rounded, color: Color(0xFF1B5E20), size: 28),
              ),
              label: gu ? '૭/૧૨ ઉતારા' : 'Records',
            ),
            NavigationDestination(
              icon: const Icon(Icons.trending_up_rounded),
              selectedIcon: Transform.scale(
                scale: 1.15,
                child: const Icon(Icons.trending_up_rounded, color: Color(0xFF1B5E20), size: 28),
              ),
              label: gu ? 'બજાર ભાવ' : 'Market Prices',
            ),
          ] : [
            NavigationDestination(
              icon: const Icon(Icons.currency_rupee_outlined),
              selectedIcon: Transform.scale(
                scale: 1.15,
                child: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF1B5E20), size: 28),
              ),
              label: gu ? 'બજાર ભાવ' : 'Market Prices',
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: Transform.scale(
                scale: 1.15,
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFF1B5E20), size: 28),
              ),
              label: gu ? 'હિસાબ' : 'Accounting',
            ),
            NavigationDestination(
              icon: const Icon(Icons.article_outlined),
              selectedIcon: Transform.scale(
                scale: 1.15,
                child: const Icon(Icons.article_rounded, color: Color(0xFF1B5E20), size: 28),
              ),
              label: gu ? '૭/૧૨ ઉતારા' : 'Records',
            ),
            NavigationDestination(
              icon: const Icon(Icons.smart_display_outlined),
              selectedIcon: Transform.scale(
                scale: 1.15,
                child: const Icon(Icons.smart_display_rounded, color: Color(0xFF1B5E20), size: 28),
              ),
              label: gu ? 'સમાચાર' : 'News',
            ),
          ],
        ),
      ),
    );
  }
}
