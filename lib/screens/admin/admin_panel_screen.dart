import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import 'admin_user_list_screen.dart';
import 'admin_global_options_screen.dart';
import 'admin_announcement_screen.dart';
import 'admin_system_controls_screen.dart';
import 'admin_faq_screen.dart';
import 'admin_price_override_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_market_banner_screen.dart';
import '../settings_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;
    final user = context.watch<AuthProvider>().user;

    // Secondary check for security
    if (user?.email != 'thevijendrachaudhary@gmail.com') {
      return const Scaffold(
        body: Center(child: Text('Access Denied')),
      );
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          gu ? 'એડમિન પેનલ' : 'Admin Panel',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: gu ? 'વપરાશકર્તા મોડ' : 'Switch to User Mode',
            icon: const Icon(Icons.visibility_rounded),
            onPressed: () => context.read<SettingsProvider>().setAdminMode(false),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => Future.delayed(const Duration(seconds: 1)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdminHero(cs, gu, user?.displayName ?? 'Admin', user, context),
              const SizedBox(height: 28),
              _buildSectionHeader(gu ? 'મેનેજમેન્ટ' : 'Management Overview', cs),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users_profiles').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 10, color: Colors.red)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }

                  final rawDocs = snapshot.data?.docs ?? [];
                  final userCount = rawDocs.where((doc) {
                    final data = doc.data();
                    final email = data['email'] as String?;
                    // Count anyone who is not the admin email
                    // If email is missing, we still count them as a user
                    return email != 'thevijendrachaudhary@gmail.com';
                  }).length;
                  
                  return Row(
                    children: [
                      Expanded(
                        child: _buildPremiumStatTile(
                          gu ? 'વપરાશકર્તાઓ' : 'Total Users',
                          userCount.toString(),
                          Icons.people_alt_rounded,
                          cs.primary,
                          cs,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUserListScreen())),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users_profiles')
                              .where('lastActive', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 15))))
                              .snapshots(),
                          builder: (context, activeSnapshot) {
                            if (activeSnapshot.hasError) {
                              return _buildPremiumStatTile(
                                gu ? 'સક્રિય' : 'Active Now',
                                '?',
                                Icons.bolt_rounded,
                                Colors.grey,
                                cs,
                              );
                            }
                            final rawActiveDocs = activeSnapshot.data?.docs ?? [];
                            final activeCount = rawActiveDocs.where((doc) {
                              final data = doc.data();
                              final email = data['email'] as String?;
                              return email != 'thevijendrachaudhary@gmail.com';
                            }).length;

                            return _buildPremiumStatTile(
                              gu ? 'સક્રિય' : 'Active Now',
                              activeCount.toString(),
                              Icons.bolt_rounded,
                              Colors.green,
                              cs,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUserListScreen(onlyActive: true))),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              _buildSectionHeader(gu ? 'ઝડપી કાર્યો' : 'System Management', cs),
              const SizedBox(height: 16),
              _buildManagementGrid(context, cs, gu),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminHero(ColorScheme cs, bool gu, String name, dynamic user, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? cs.primaryContainer : null,
        gradient: isDark ? null : LinearGradient(
          colors: [cs.primary, cs.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isDark ? cs.shadow : cs.primary).withOpacity(isDark ? 0.2 : 0.3), 
            blurRadius: 20, 
            offset: const Offset(0, 10)
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? cs.onPrimaryContainer.withOpacity(0.12) : Colors.white.withOpacity(0.2),
                child: Icon(Icons.admin_panel_settings, color: isDark ? cs.onPrimaryContainer : Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gu ? 'હેલો, એડમિન' : 'Hello, Admin',
                    style: TextStyle(
                      color: isDark ? cs.onPrimaryContainer.withOpacity(0.7) : Colors.white.withOpacity(0.8), 
                      fontSize: 14,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                  Text(
                    name,
                    style: TextStyle(
                      color: isDark ? cs.onPrimaryContainer : Colors.white, 
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(color: isDark ? cs.onPrimaryContainer.withOpacity(0.5) : Colors.white.withOpacity(0.6), fontSize: 11),
                  ),
                  Text(
                    'UID: ${user?.uid ?? ''}',
                    style: TextStyle(color: isDark ? cs.onPrimaryContainer.withOpacity(0.3) : Colors.white.withOpacity(0.4), fontSize: 8),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeroStat(
                gu ? 'સિસ્ટમ સ્ટેટસ' : 'System Health', 
                gu ? 'સામાન્ય' : 'All Systems GO', 
                Icons.check_circle_rounded,
                isDark,
                cs
              ),
              _buildHeroStat(
                gu ? 'સિક્યુરિટી' : 'Security', 
                gu ? 'સાક્રિય' : 'Protected', 
                Icons.shield_rounded,
                isDark,
                cs
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value, IconData icon, bool isDark, ColorScheme cs) {
    final contentColor = isDark ? cs.onPrimaryContainer : Colors.white;
    return Row(
      children: [
        Icon(icon, color: contentColor.withOpacity(0.9), size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: contentColor.withOpacity(0.6), fontSize: 10)),
            Text(value, style: TextStyle(color: contentColor, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildPremiumStatTile(String label, String value, IconData icon, Color accentColor, ColorScheme cs, {VoidCallback? onTap}) {
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(height: 16),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -1)),
              Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementGrid(BuildContext context, ColorScheme cs, bool gu) {
    final List<Map<String, dynamic>> items = [
      {'title': gu ? 'રિપોર્ટ્સ' : 'Finance Reports', 'icon': Icons.insights_rounded, 'color': Colors.blue, 'screen': const AdminReportsScreen()},
      {'title': gu ? 'જાહેરાતો' : 'Announcements', 'icon': Icons.campaign_rounded, 'color': Colors.orange, 'screen': const AdminAnnouncementScreen()},
      {'title': gu ? 'ભાવ ઓવરરાઇડ' : 'Price Overrides', 'icon': Icons.sell_rounded, 'color': Colors.purple, 'screen': const AdminPriceOverrideScreen()},
      {'title': gu ? 'ગ્લોબલ ઓપ્શન્સ' : 'Global Settings', 'icon': Icons.public_rounded, 'color': Colors.teal, 'screen': const AdminGlobalOptionsScreen()},
      {'title': gu ? 'સિસ્ટમ કંટ્રોલ' : 'System Control', 'icon': Icons.settings_suggest_rounded, 'color': Colors.indigo, 'screen': const AdminSystemControlsScreen()},
      {'title': gu ? 'પ્રશ્નોત્તરી (FAQ)' : 'Manage FAQs', 'icon': Icons.quiz_rounded, 'color': Colors.brown, 'screen': const AdminFaqScreen()},
      {'title': gu ? 'માર્કેટ બેનર' : 'Market Banners', 'icon': Icons.image_rounded, 'color': Colors.deepOrange, 'screen': const AdminMarketBannerScreen()},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => item['screen'])),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: item['color'].withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(item['icon'], color: item['color'], size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item['title'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface, letterSpacing: -0.5),
      ),
    );
  }
}
