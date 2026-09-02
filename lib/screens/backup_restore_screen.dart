import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../services/backup_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupService _backupService = BackupService();

  Future<void> _handleSync() async {
    final settings = context.read<SettingsProvider>();
    final syncProvider = context.read<SyncProvider>();
    final gu = settings.isGujarati;

    HapticFeedback.mediumImpact();
    // Bug fix: SyncProvider catches all exceptions internally and never rethrows,
    // so a try/catch here would always appear to succeed. Instead, we check
    // lastSyncError *after* the await to determine the real outcome.
    await syncProvider.requestSync(immediate: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    final error = syncProvider.lastSyncError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(gu ? 'ભૂલ: $error' : 'Sync failed: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(gu ? 'બેકઅપ સફળતાપૂર્વક પૂર્ણ થયું!' : 'Backup completed successfully!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleExport() async {
    final gu = context.read<SettingsProvider>().isGujarati;
    HapticFeedback.lightImpact();
    try {
      await _backupService.exportBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(gu ? 'નિકાસમાં ભૂલ: $e' : 'Export error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleImport() async {
    final gu = context.read<SettingsProvider>().isGujarati;
    HapticFeedback.lightImpact();
    
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
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(gu ? 'ઇમ્પોર્ટમાં ભૂલ: $e' : 'Import error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final syncProvider = context.watch<SyncProvider>();
    final gu = settings.isGujarati;
    final cs = Theme.of(context).colorScheme;

    final lastSync = syncProvider.lastSyncTime != null
        ? DateFormat('dd MMM, hh:mm a').format(syncProvider.lastSyncTime!)
        : (gu ? 'ક્યારેય નહીં' : 'Never');

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(gu ? 'બેકઅપ અને રિસ્ટોર' : 'Backup & Restore'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupHeader(gu ? 'ક્લાઉડ બેકઅપ' : 'Cloud Backup', cs),
            _buildSyncCard(syncProvider, lastSync, gu, cs),
            const SizedBox(height: 24),
            _buildGroupHeader(gu ? 'લોકલ બેકઅપ (ફાઈલ)' : 'Local Backup (File)', cs),
            _buildFileBackupCard(gu, cs),
            const SizedBox(height: 32),
            _buildSecurityNote(gu, cs),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: cs.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSyncCard(SyncProvider syncProvider, String lastSync, bool gu, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  syncProvider.isSyncing ? Icons.sync : Icons.cloud_done_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gu ? 'ઓટોમેટિક સિંક' : 'Automatic Sync',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${gu ? 'છેલ્લું સિંક:' : 'Last sync:'} $lastSync',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: syncProvider.isSyncing ? null : _handleSync,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: syncProvider.isSyncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      gu ? 'હમણાં સિંક કરો' : 'Sync Now',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileBackupCard(bool gu, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: _handleExport,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: _buildIconBox(Icons.file_upload_outlined, cs.primary, cs),
            title: Text(gu ? 'ફાઇલમાં એક્સપોર્ટ કરો' : 'Export Data File', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(gu ? 'તમારો ડેટા JSON ફાઈલ તરીકે સાચવો' : 'Save your data as a JSON file'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          Divider(height: 1, indent: 70, color: cs.outlineVariant.withOpacity(0.5)),
          ListTile(
            onTap: _handleImport,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: _buildIconBox(Icons.file_download_outlined, cs.secondary, cs),
            title: Text(gu ? 'ફાઇલમાંથી ઇમ્પોર્ટ કરો' : 'Import Data File', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(gu ? 'બેકઅપ ફાઇલમાંથી ડેટા પાછો લાવો' : 'Restore data from backup file'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBox(IconData icon, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildSecurityNote(bool gu, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.secondaryContainer),
      ),
      child: Row(
        children: [
          Icon(Icons.security_rounded, color: cs.secondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              gu 
                ? 'તમારો ડેટા સુરક્ષિત રીતે સંગ્રહિત છે. અમે નિયમિતપણે બેકઅપ લેવાની ભલામણ કરીએ છીએ.' 
                : 'Your data is securely stored. We recommend taking regular backups.',
              style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
