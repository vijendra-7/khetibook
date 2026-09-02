import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_help_screen.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/auth_provider.dart'; // Added import for AuthProvider
import '../utils/custom_options_manager.dart';
import '../utils/language_mapper.dart';
import '../services/backup_service.dart';
import 'backup_restore_screen.dart';
import '../providers/custom_options_provider.dart';
import '../providers/global_options_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedCategory = CustomOptionsManager.categorysCrops;
  String _appVersion = '';
  final BackupService _backupService = BackupService();
  final ScrollController _dropdownScrollController = ScrollController();

  Future<void> _handleSync() async {
    final settings = context.read<SettingsProvider>();
    final syncProvider = context.read<SyncProvider>();
    final gu = settings.isGujarati;

    try {
      await syncProvider.requestSync(immediate: true);
      // Success snackbar is now handled by provider or still here for UX
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(gu ? 'બેકઅપ સફળતાપૂર્વક પૂર્ણ થયું!' : 'Backup completed successfully!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(gu ? 'ભૂલ: $e' : 'Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleExport() async {
    final gu = context.read<SettingsProvider>().isGujarati;
    try {
      await _backupService.exportBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(gu ? 'નિકાસમાં ભૂલ: $e' : 'Export error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleImport() async {
    final gu = context.read<SettingsProvider>().isGujarati;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(gu ? 'ડેટા ઇમ્પોર્ટ?' : 'Import Data?'),
        content: Text(gu 
          ? 'આ તમારા હાલના ડેટાને બેકઅપ ફાઇલમાં રહેલા ડેટા સાથે મર્જ કરશે (અથવા ઓવરરાઈટ કરશે જો તે સમાન હોય તો). શું તમે ચાલુ રાખવા માંગો છો?' 
          : 'This will merge (or overwrite if duplicate) your current data with the data in the backup file. Do you want to continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(gu ? 'ના' : 'No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(gu ? 'હા, ઇમ્પોર્ટ કરો' : 'Yes, Import')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await _backupService.importBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result), duration: const Duration(seconds: 2)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(gu ? 'ઇમ્પોર્ટમાં ભૂલ: $e' : 'Import error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  final _categories = [
    (CustomOptionsManager.categorysCrops, 'Crops', 'પ્રકાર'),
    (CustomOptionsManager.categoryServiceProviders, 'Providers', 'પ્રદાતા'),
    (CustomOptionsManager.categoryTractorProviders, 'Tractor Co.', 'ટ્રેક્ટર'),
    (CustomOptionsManager.categoryInvestmentTypes, 'Inv. Types', 'ખર્ચો'),
    (CustomOptionsManager.categoryEquipmentTypes, 'Equipment', 'ઉપકરણ'),
    (CustomOptionsManager.categoryBuyers, 'Buyers', 'ખ.'),
    (CustomOptionsManager.categoryDrivers, 'Drivers', 'ડ્રાઈ.'),
    (CustomOptionsManager.categoryDawa, 'Dawa', 'દવા'),
    (CustomOptionsManager.categoryKhatar, 'Khatar', 'ખાતર'),
    (CustomOptionsManager.categoryHelpers, 'Partners', 'ભાગીદાર'),
    (CustomOptionsManager.categoryFields, 'Fields', 'ખેતર'),
    (CustomOptionsManager.categoryBatakaSeeds, 'Bataka Biyaran', 'બટાકા બિયારણ'),
    (CustomOptionsManager.categoryMagfaliSeeds, 'Magfali Biyaran', 'મગફળી બિયારણ'),
    (CustomOptionsManager.categoryGhauSeeds, 'Ghau Biyaran', 'ઘઉં બિયારણ'),
    (CustomOptionsManager.categoryTarbuchSeeds, 'Tarbuch Biyaran', 'તરબૂચ બિયારણ'),
    (CustomOptionsManager.categoryBajariSeeds, 'Bajari Biyaran', 'બાજરી બિયારણ'),
  ];

  static const List<(String, String, String)> _apmcCrops = [
    ('potato_vjpatel', 'Potato (V.J.Patel)', 'બટાકા (V.J.Patel)'),
    ('potato', 'Potato', 'બટાકા'),
    ('castor', 'Castor', 'એરંડા'),
    ('mustard', 'Mustard', 'રાયડો'),
    ('bajri', 'Bajri', 'બાજરી'),
    ('wheat', 'Wheat', 'ઘઉં'),
    ('rajgaro', 'Rajgaro', 'રાજગરો'),
    ('cumin', 'Cumin', 'જીરું'),
    ('chana', 'Chana', 'ચણા'),
    ('asaliyo', 'Asaliyo', 'અસાળીયો'),
    ('groundnut', 'Groundnut', 'મગફળી'),
    ('rajka bajari', 'Rajka Bajari', 'રજકા બાજરી'),
    ('sarsav', 'Sarsav', 'સરસવ'),
    ('methi', 'Methi', 'મેથી'),
  ];

  static const List<(String, String, String)> _agraCrops = [
    ('potato_agra_agra apmc', 'Agra APMC', 'Agra APMC'),
    ('potato_agra_fatehabad apmc', 'Fatehabad APMC', 'Fatehabad APMC'),
    ('potato_agra_jagnair apmc', 'Jagnair APMC', 'Jagnair APMC'),
    ('potato_agra_jarar apmc', 'Jarar APMC', 'Jarar APMC'),
    ('potato_agra_samsabad apmc', 'Samsabad APMC', 'Samsabad APMC'),
    ('potato_agra_achnera apmc', 'Achnera APMC', 'Achnera APMC'),
    ('potato_agra_khairagarh apmc', 'Khairagarh APMC', 'Khairagarh APMC'),
    ('potato_agra_fatehpur sikri apmc', 'Fatehpur Sikri APMC', 'F. Sikri APMC'),
  ];

  @override
  void dispose() {
    _dropdownScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = 'v${info.version}');
  }

  Future<void> _loadOptions() async {
    await context.read<CustomOptionsProvider>().loadOptions(_selectedCategory);
  }

  Future<void> _addOption() async {
    final ctrl = TextEditingController();
    final gu = context.read<SettingsProvider>().isGujarati;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(gu ? 'ઉમેરો' : 'Add Option'),
        content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: gu ? 'નામ' : 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await context.read<CustomOptionsProvider>().addOption(_selectedCategory, result);
    }
  }

  Future<void> _removeOption(String value) async {
    final gu = context.read<SettingsProvider>().isGujarati;
    final cs = Theme.of(context).colorScheme;

    // 1. Check if can delete (no entries)
    final canDelete = await CustomOptionsManager.canDeleteOption(_selectedCategory, value);
    if (!canDelete) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(gu ? 'કાઢી શકાતું નથી' : 'Cannot Delete'),
            content: Text(gu 
              ? 'આ પાક માટે તમારી પાસે પહેલેથી જ એન્ટ્રીઓ છે. કૃપા કરીને તેને કાઢી નાખતા પહેલા તે એન્ટ્રીઓ કાઢી નાખો.' 
              : 'You already have entries for this crop. Please delete those entries before removing the crop.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
      return;
    }

    // 2. Confirm Deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(gu ? 'ખરેખર કાઢી નાખવું છે?' : 'Confirm Deletion'),
        content: Text(gu 
          ? 'શું તમે ખરેખર "$value" ને લિસ્ટમાંથી કાઢી નાખવા માંગો છો?' 
          : 'Are you sure you want to remove "$value" from the list?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(gu ? 'રદ કરો' : 'Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(gu ? 'હા, કાઢી નાખો' : 'Remove', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<CustomOptionsProvider>().removeOption(_selectedCategory, value);
    }
  }

  void _navigateToBackup(bool gu) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupRestoreScreen()));
  }

  void _navigateToHelp(bool gu) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const UserHelpScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final customProvider = context.watch<CustomOptionsProvider>();
    final globalMetadata = context.watch<GlobalOptionsProvider>();
    final settings = context.watch<SettingsProvider>();
    final gu = settings.isGujarati;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(cs, gu),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Language & Theme Group ---
                  _buildGroupHeader(gu ? 'દેખાવ અને ભાષા' : 'Appearance & Language', cs, gu: gu),
                  _buildPremiumCard(
                    cs,
                    children: [
                      _buildLanguageSelector(settings, gu, cs),
                      const _Divider(),
                      _buildThemeSelector(settings, gu, cs),
                    ],
                  ),
                  const SizedBox(height: 24),


                  // --- Dropdown Management ---
                  _buildGroupHeader(gu ? 'ડ્રોપડાઉન વ્યવસ્થાપન' : 'Manage List Options', cs, gu: gu),
                  _buildDropdownManager(gu, cs, settings, customProvider, globalMetadata),
                  const SizedBox(height: 24),


                  // --- Market Visibility Group ---
                  _buildGroupHeader(gu ? 'માર્કેટ વિઝિબિલિટી' : 'Market Visibility', cs, gu: gu),
                  _buildPremiumCard(
                    cs,
                    children: [
                      _buildExpansionTile(
                        title: gu ? 'APMC બજાર ભાવ (ડીસા)' : 'APMC Market Prices (Deesa)',
                        icon: Icons.analytics_outlined,
                        color: cs.primary,
                        cs: cs,
                        children: _apmcCrops.map((crop) => _buildVisibilityToggle(
                          label: gu ? crop.$3 : crop.$2,
                          value: !settings.hiddenApmcCrops.contains(crop.$1),
                          onChanged: (_) => settings.toggleApmcCrop(crop.$1),
                          cs: cs,
                        )).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),


                  // --- Account Group ---
                  _buildGroupHeader(gu ? 'ખાતું' : 'Account', cs, gu: gu),
                  _buildProfileCard(gu, cs),
                  const SizedBox(height: 24),

                  // --- Backup & Sync Group ---
                  _buildGroupHeader(gu ? 'બેકઅપ અને સુરક્ષા' : 'Backup & Security', cs, gu: gu),
                  _buildPremiumCard(
                    cs,
                    children: [
                      ListTile(
                        onTap: () => _navigateToBackup(gu),
                        leading: _buildModernIcon(Icons.backup_outlined, cs.primary, cs),
                        title: Text(gu ? 'બેકઅપ અને રિસ્ટોર' : 'Backup & Restore'),
                        subtitle: Text(gu ? 'ક્લાઉડ સિંક અને ફાઇલ બેકઅપ' : 'Cloud sync and file backup'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- About Section ---
                  _buildAboutCard(gu, cs),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ColorScheme cs, bool gu) {
    return SliverAppBar.large(
      expandedHeight: 140,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(
        gu ? 'સેટિંગ્સ' : 'Settings',
        style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.primaryContainer.withOpacity(0.4),
                cs.surface,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, ColorScheme cs, {bool gu = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        gu ? title : title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: cs.primary,
          // English uses wide letter-spacing; Gujarati needs tighter spacing
          letterSpacing: gu ? 0.3 : 1.2,
        ),
      ),
    );
  }

  Widget _buildPremiumCard(ColorScheme cs, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildLanguageSelector(SettingsProvider settings, bool gu, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language_rounded, color: cs.primary, size: 22),
              const SizedBox(width: 12),
              Text(
                gu ? 'ભાષા પસંદ કરો' : 'Choose Language',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LanguageOption(
                  label: 'English',
                  selected: !gu,
                  onTap: () => settings.setLanguage(false),
                  cs: cs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LanguageOption(
                  label: 'ગુજરાતી',
                  selected: gu,
                  onTap: () => settings.setLanguage(true),
                  cs: cs,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(SettingsProvider settings, bool gu, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: cs.primary, size: 22),
              const SizedBox(width: 12),
              Text(
                gu ? 'થીમ પસંદ કરો' : 'Choose Theme',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ThemeOption(
                icon: Icons.light_mode_outlined,
                selected: settings.themeMode == ThemeMode.light,
                onTap: () => settings.setThemeMode(ThemeMode.light),
                cs: cs,
              ),
              const SizedBox(width: 12),
              _ThemeOption(
                icon: Icons.dark_mode_outlined,
                selected: settings.themeMode == ThemeMode.dark,
                onTap: () => settings.setThemeMode(ThemeMode.dark),
                cs: cs,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(bool gu, ColorScheme cs) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.primary.withOpacity(0.2), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: cs.primaryContainer,
                        backgroundImage: user.photoURL != null ? CachedNetworkImageProvider(user.photoURL!) : null,
                        child: user.photoURL == null ? Icon(Icons.person, color: cs.primary, size: 32) : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName ?? (gu ? 'વપરાશકર્તા' : 'User'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.5),
                          ),
                          Text(
                            user.email ?? '',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const _Divider(),
              ListTile(
                onTap: _handleSignOut,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                ),
                title: Text(gu ? 'સાઇન આઉટ' : 'Sign Out', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                trailing: Icon(Icons.chevron_right_rounded, color: cs.outlineVariant.withOpacity(0.5)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSignOut() async {
    final auth = context.read<AuthProvider>();
    final gu = context.read<SettingsProvider>().isGujarati;
    final cs = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(gu ? 'સાઇન આઉટ?' : 'Sign Out?'),
        content: Text(gu ? 'શું તમે ખરેખર સાઇન આઉટ કરવા માંગો છો?' : 'Are you sure you want to log out?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(gu ? 'ના' : 'No', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(gu ? 'હા, સાઇન આઉટ' : 'Sign Out', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await auth.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Widget _buildExpansionTile({
    required String title,
    required IconData icon,
    required Color color,
    required ColorScheme cs,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      shape: const RoundedRectangleBorder(),
      collapsedShape: const RoundedRectangleBorder(),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: children,
    );
  }

  Widget _buildVisibilityToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ColorScheme cs,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14))),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownManager(
    bool gu,
    ColorScheme cs,
    SettingsProvider settings,
    CustomOptionsProvider customProvider,
    GlobalOptionsProvider globalMetadata,
  ) {
    return _buildPremiumCard(
      cs,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: ChoiceChip(
                      label: Text(gu ? cat.$3 : cat.$2),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat.$1);
                        _loadOptions();
                      },
                      selectedColor: cs.primaryContainer,
                      labelStyle: TextStyle(
                        color: selected ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      showCheckmark: false,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 250),
          child: ShaderMask(
            shaderCallback: (Rect rect) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.purple.withOpacity(0.0), // Start transparent
                  Colors.black.withOpacity(1.0), // Middle opaque
                  Colors.black.withOpacity(1.0),
                  Colors.purple.withOpacity(0.0), // End transparent
                ],
                stops: const [0.0, 0.08, 0.92, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: Scrollbar(
              controller: _dropdownScrollController,
              thumbVisibility: true,
              thickness: 4,
              radius: const Radius.circular(8),
              child: ListView(
                controller: _dropdownScrollController,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ...customProvider.getPredefined(_selectedCategory).map((opt) => _buildOptionTile(
                        opt,
                        true,
                        cs,
                        gu,
                        _selectedCategory,
                        globalMetadata.getGlobalCropMap(gu),
                        globalMetadata.getGlobalInvestmentTypeMap(gu),
                      )),
                  ...customProvider.getCustom(_selectedCategory).map((opt) => _buildOptionTile(
                        opt,
                        false,
                        cs,
                        gu,
                        _selectedCategory,
                        globalMetadata.getGlobalCropMap(gu),
                        globalMetadata.getGlobalInvestmentTypeMap(gu),
                      )),
                ],
              ),
            ),
          ),
        ),
        ListTile(
          onTap: _addOption,
          leading: Icon(Icons.add_circle_outline_rounded, color: cs.primary),
          title: Text(
            gu ? 'નવો વિકલ્પ ઉમેરો' : 'Add New Option',
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile(
    String label,
    bool isPredefined,
    ColorScheme cs,
    bool gu,
    String category,
    Map<String, String> globalCropMap,
    Map<String, String> globalInvestmentTypeMap,
  ) {
    // Localize the label based on its category
    final displayLabel = LanguageMapper.localizedOption(
      category,
      label,
      gu,
      globalCropMap: globalCropMap,
      globalInvestmentTypeMap: globalInvestmentTypeMap,
    );
    
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.label_outline_rounded,
        size: 18,
        color: isPredefined ? cs.outline : cs.primary,
      ),
      title: Text(displayLabel, style: const TextStyle(fontSize: 14)),
      trailing: IconButton(
        icon: Icon(Icons.remove_circle_outline_rounded, color: cs.error, size: 18),
        onPressed: () => _removeOption(label), // Always use the raw English value for database operations
      ),
    );
  }

  Widget _buildAboutCard(bool gu, ColorScheme cs) {
    return _buildPremiumCard(
      cs,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildModernIcon(Icons.info_outline_rounded, cs.secondary, cs),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'KhetiBook',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _appVersion,
                          style: TextStyle(color: cs.outline, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ખેડૂત પુત્ર દ્વારા બનાવેલ ખેડૂત એપ 👳🏻‍♂️',
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernIcon(IconData icon, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _LanguageOption({required this.label, required this.selected, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: 1.5),
          boxShadow: selected ? [BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? cs.onPrimary : cs.onSurface,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _ThemeOption({required this.icon, required this.selected, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: 1.5),
          ),
          child: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant, size: 24),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5));
}
