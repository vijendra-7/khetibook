import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/investment.dart';
import '../../models/output.dart';
import '../../models/helper_transaction.dart';
import '../../models/custom_option.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final String userId;
  final String userName;
  final String email;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          gu ? 'વપરાશકર્તા વિગત' : 'User Detail',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users_profiles').doc(userId).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final isBlocked = data['isBlocked'] ?? false;
          final appVersion = data['appVersion'] as String?;
          final forceResync = data['forceResync'] ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserHeader(cs, gu, appVersion),
                const SizedBox(height: 32),
                _buildSectionHeader(gu ? 'તાજેતરની પ્રવૃત્તિ' : 'Recent Activity', cs),
                const SizedBox(height: 16),
                _buildActivitySection(context, 'investments', gu ? 'રોકાણ' : 'Investments', Icons.trending_up_rounded, cs, gu),
                const SizedBox(height: 12),
                _buildActivitySection(context, 'outputs', gu ? 'ઉત્પાદન' : 'Outputs', Icons.inventory_2_rounded, cs, gu),
                const SizedBox(height: 12),
                _buildActivitySection(context, 'helper_transactions', gu ? 'મજૂરી' : 'Helper Txns', Icons.people_rounded, cs, gu),
                const SizedBox(height: 12),
                _buildActivitySection(context, 'custom_options', gu ? 'વિકલ્પો' : 'Custom Options', Icons.settings_rounded, cs, gu),
                const SizedBox(height: 40),
                _buildModerationSection(context, cs, gu, isBlocked, appVersion, forceResync),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModerationSection(BuildContext context, ColorScheme cs, bool gu, bool isBlocked, String? appVersion, bool isForceResyncActive) {
    final supportsRemoteSync = appVersion != null && appVersion.compareTo('1.2.1') >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isBlocked ? Colors.red.withOpacity(0.05) : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isBlocked ? Colors.red.withOpacity(0.3) : Colors.transparent),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isBlocked ? Icons.warning_rounded : Icons.security_rounded, color: isBlocked ? Colors.red : cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                gu ? 'વપરાશકર્તા નિયંત્રણ' : 'Account Management',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _toggleBlockStatus(context, isBlocked, gu),
              icon: Icon(isBlocked ? Icons.gavel_rounded : Icons.block_rounded, size: 20),
              label: Text(
                isBlocked 
                  ? (gu ? 'બિન-પ્રતિબંધિત કરો' : 'Unblock Account') 
                  : (gu ? 'પ્રતિબંધિત કરો' : 'Block Account'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isBlocked ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          if (supportsRemoteSync) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isForceResyncActive ? null : () async {
                   await FirebaseFirestore.instance.collection('users_profiles').doc(userId).update({'forceResync': true});
                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remote Sync signal sent! Execution is silent and immediate.'), backgroundColor: Colors.green));
                   }
                },
                icon: const Icon(Icons.sync_rounded, size: 20),
                label: Text(
                  isForceResyncActive ? 'Sync Signal Sent...' : 'Force Cloud Re-Sync',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
          if (isBlocked)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                gu ? 'આ વપરાશકર્તા હાલમાં પ્રતિબંધિત છે' : 'This user is currently blocked from app access',
                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleBlockStatus(BuildContext context, bool currentStatus, bool gu) async {
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentStatus ? (gu ? 'બિન-પ્રતિબંધિત કરો?' : 'Unblock User?') : (gu ? 'પ્રતિબંધિત કરો?' : 'Block User?')),
        content: Text(currentStatus 
          ? (gu ? 'શું તમે આ વપરાશકર્તાને બિન-પ્રતિબંધિત કરવા માંગો છો?' : 'Are you sure you want to restore access for this user?')
          : (gu ? 'શું તમે આ વપરાશકર્તાને પ્રતિબંધિત કરવા માંગો છો?' : 'Are you sure you want to block this user from accessing the app?')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(gu ? 'રદ કરો' : 'Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              currentStatus ? (gu ? 'હા' : 'Unblock') : (gu ? 'હા, પ્રતિબંધિત કરો' : 'Block'),
              style: TextStyle(color: currentStatus ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final docRef = FirebaseFirestore.instance.collection('users_profiles').doc(userId);
      debugPrint('Attempting to update block status at: ${docRef.path}');
      try {
        await docRef.set({
          'isBlocked': !currentStatus,
          'blockedAt': !currentStatus ? FieldValue.serverTimestamp() : null,
          'lastModeratedBy': 'Admin',
        }, SetOptions(merge: true));
        debugPrint('User block status updated successfully for $userId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(!currentStatus ? 'User Blocked' : 'User Unblocked'),
              backgroundColor: !currentStatus ? Colors.red : Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error toggling block status: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildUserHeader(ColorScheme cs, bool gu, String? appVersion) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.primary.withOpacity(0.2), width: 2),
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: cs.primaryContainer,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'UID: ${userId.substring(0, 8)}...',
                        style: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.7), fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (appVersion != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'v$appVersion',
                          style: TextStyle(color: cs.onPrimaryContainer, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme cs) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: cs.onSurface,
        letterSpacing: -0.5
      ),
    );
  }

  Widget _buildActivitySection(BuildContext context, String collectionName, String title, IconData icon, ColorScheme cs, bool gu) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: cs.primary, size: 20),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(userId).collection(collectionName).snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Text(
                gu ? '$count એન્ટ્રીઓ' : '$count entries',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              );
            },
          ),
          children: [
            Container(
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection(collectionName)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  final allDocs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
                  allDocs.sort((a, b) {
                    final da = a.data() as Map<String, dynamic>? ?? {};
                    final db = b.data() as Map<String, dynamic>? ?? {};
                    
                    int getMs(Map<String, dynamic> d) {
                      final val = d['date'] ?? d['updatedAt'];
                      if (val is Timestamp) return val.millisecondsSinceEpoch;
                      if (val is int) return val;
                      return 0;
                    }
                    
                    return getMs(db).compareTo(getMs(da));
                  });
                  final docs = allDocs.take(10).toList();
                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(child: Text(gu ? 'કોઈ ડેટા નથી' : 'No activity found', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant.withOpacity(0.3)),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return _buildDataRow(data, collectionName, cs);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(Map<String, dynamic> data, String collection, ColorScheme cs) {
    String title = 'Entry';
    String subtitle = '';
    
    try {
      if (collection == 'investments') {
        final inv = Investment.fromMap(data);
        final provider = inv.serviceProvider.isNotEmpty ? inv.serviceProvider : 'Unknown';
        title = '$provider - ${inv.displayInvestmentType}';
        subtitle = '₹${inv.totalAmount.toStringAsFixed(0)}';
      } else if (collection == 'outputs') {
        final out = Output.fromMap(data);
        final soldTo = out.soldTo.isNotEmpty ? out.soldTo : 'Unknown';
        title = '${out.crop} - $soldTo';
        subtitle = '${out.bharati} units @ ₹${out.pricePer20kg.toStringAsFixed(0)}';
      } else if (collection == 'helper_transactions') {
        final txn = HelperTransaction.fromMap(data);
        final helper = txn.helperName.isNotEmpty ? txn.helperName : 'Helper';
        title = '$helper - ${txn.transactionType}';
        subtitle = '₹${txn.totalAmount.toStringAsFixed(0)}';
      } else if (collection == 'custom_options') {
        final opt = CustomOption.fromMap(data);
        title = '${opt.category}: ${opt.value}';
        subtitle = 'Custom Opt';
      }
    } catch (e) {
      debugPrint('Error parsing admin data for $collection: $e');
    }

    final dateField = data['date'] ?? data['updatedAt'];
    DateTime date = DateTime.now();
    if (dateField is Timestamp) {
      date = dateField.toDate();
    } else if (dateField is int) {
      date = DateTime.fromMillisecondsSinceEpoch(dateField);
    }
    
    final dateStr = DateFormat('dd MMM').format(date);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      trailing: Text(dateStr, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withOpacity(0.6))),
    );
  }
}
