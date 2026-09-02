import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/settings_provider.dart';

import 'admin_user_detail_screen.dart';

enum ActiveTimeFilter {
  fifteenMins,
  thirtyMins,
  oneHour,
  today,
}

class AdminUserListScreen extends StatefulWidget {
  final bool onlyActive;
  final String? title;

  const AdminUserListScreen({
    super.key,
    this.onlyActive = false,
    this.title,
  });

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  ActiveTimeFilter _selectedFilter = ActiveTimeFilter.fifteenMins;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          widget.title ?? (gu ? 'વપરાશકર્તાઓની યાદી' : 'User List'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          if (widget.onlyActive) _buildFilterChips(cs, gu),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _getQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rawDocs = snapshot.data?.docs ?? [];
                // Filter out admin client-side to avoid complex Firestore index requirements
                final docs = rawDocs.where((doc) {
                  final data = doc.data();
                  return data['email'] != 'thevijendrachaudhary@gmail.com';
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(gu ? 'કોઈ વપરાશકર્તાઓ મળ્યા નથી' : 'No users found'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final name = data['displayName'] ?? 'Unknown';
                    final email = data['email'] ?? 'No Email';
                    final photoUrl = data['photoURL'] as String?;
                    final lastActive = data['lastActive'] as Timestamp?;
                    
                    bool isActiveNow = false;
                    if (lastActive != null) {
                      isActiveNow = DateTime.now().difference(lastActive.toDate()).inMinutes < 5;
                    }

                    String lastActiveStr = 'Never';
                    if (lastActive != null) {
                      if (DateFormat('yyyyMMdd').format(lastActive.toDate()) == DateFormat('yyyyMMdd').format(DateTime.now())) {
                        lastActiveStr = '${gu ? 'આજે' : 'Today'}, ${DateFormat('hh:mm a').format(lastActive.toDate())}';
                      } else {
                        lastActiveStr = DateFormat('dd MMM, hh:mm a').format(lastActive.toDate());
                      }
                    }

                    return Material(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminUserDetailScreen(
                                userId: data['uid'] ?? docs[index].id,
                                userName: name,
                                email: email,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: cs.primary.withOpacity(0.1),
                                    backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                                    child: photoUrl == null ? Icon(Icons.person_rounded, color: cs.primary, size: 30) : null,
                                  ),
                                  if (isActiveNow)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: cs.surface, width: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      email,
                                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          isActiveNow ? Icons.bolt_rounded : Icons.access_time_rounded,
                                          size: 14,
                                          color: isActiveNow ? Colors.green : cs.outline,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isActiveNow ? (gu ? 'સક્રિય' : 'Active Now') : lastActiveStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isActiveNow ? Colors.green : cs.onSurfaceVariant,
                                            fontWeight: isActiveNow ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: cs.outline),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme cs, bool gu) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _filterChip(ActiveTimeFilter.fifteenMins, gu ? '૧૫ મિનિટ' : '15 min', cs),
          const SizedBox(width: 8),
          _filterChip(ActiveTimeFilter.thirtyMins, gu ? '૩૦ મિનિટ' : '30 min', cs),
          const SizedBox(width: 8),
          _filterChip(ActiveTimeFilter.oneHour, gu ? '૧ કલાક' : '1 hour', cs),
          const SizedBox(width: 8),
          _filterChip(ActiveTimeFilter.today, gu ? 'આજે' : 'Today', cs),
        ],
      ),
    );
  }

  Widget _filterChip(ActiveTimeFilter filter, String label, ColorScheme cs) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filter;
          });
        }
      },
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Query<Map<String, dynamic>> _getQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users_profiles');
    
    if (widget.onlyActive) {
      DateTime threshold;
      final now = DateTime.now();
      
      switch (_selectedFilter) {
        case ActiveTimeFilter.fifteenMins:
          threshold = now.subtract(const Duration(minutes: 15));
          break;
        case ActiveTimeFilter.thirtyMins:
          threshold = now.subtract(const Duration(minutes: 30));
          break;
        case ActiveTimeFilter.oneHour:
          threshold = now.subtract(const Duration(hours: 1));
          break;
        case ActiveTimeFilter.today:
          threshold = DateTime(now.year, now.month, now.day);
          break;
      }
      
      query = query
        .where('lastActive', isGreaterThanOrEqualTo: Timestamp.fromDate(threshold))
        .orderBy('lastActive', descending: true);
    }
    
    // For All Users (onlyActive = false), we don't add any where or orderBy 
    // to ensure 100% of documents in the collection are returned.
    
    return query;
  }
}
