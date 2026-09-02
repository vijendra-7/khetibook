import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class AdminResponsesScreen extends StatelessWidget {
  final String announcementId;
  final String announcementTitle;

  const AdminResponsesScreen({
    super.key,
    required this.announcementId,
    required this.announcementTitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gu ? 'પ્રતિભાવો' : 'Responses', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(announcementTitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcement_responses')
            .where('announcementId', isEqualTo: announcementId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text(gu ? 'કોઈ પ્રતિસાદ હજુ સુધી મળ્યો નથી' : 'No responses yet'));
          }

          // Group for poll results breakdown
          final pollResults = <String, int>{};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final selections = data['pollSelections'] as List<dynamic>? ?? [];
            if (selections.isEmpty) {
              // Backward compatibility for single selection
              final oldSelection = data['pollSelection'] as String?;
              if (oldSelection != null && oldSelection.isNotEmpty) {
                pollResults[oldSelection] = (pollResults[oldSelection] ?? 0) + 1;
              }
            } else {
              for (var opt in selections) {
                final s = opt.toString();
                pollResults[s] = (pollResults[s] ?? 0) + 1;
              }
            }
          }

          return CustomScrollView(
            slivers: [
              if (pollResults.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildPollSummary(context, cs, gu, pollResults),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return _buildResponseItem(context, cs, gu, data, docs[index].id);
                    },
                    childCount: docs.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPollSummary(BuildContext context, ColorScheme cs, bool gu, Map<String, int> results) {
    // For MSQ, total might be > total respondents, but we'll show percentages relative to total entries? 
    // Or just count of votes. Let's stick to counts/percentages.
    final total = results.values.fold(0, (sum, val) => sum + val);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                gu ? 'પોલ પરિણામો' : 'Poll Results',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...results.entries.map((entry) {
            final percent = total > 0 ? (entry.value / total) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('${entry.value} ${gu ? 'વોટ' : 'votes'} (${(percent * 100).toStringAsFixed(1)}%)'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                      backgroundColor: cs.surfaceContainerHighest,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResponseItem(BuildContext context, ColorScheme cs, bool gu, Map<String, dynamic> data, String docId) {
    final name = data['userName'] ?? 'Anonymous';
    final email = data['userEmail'] ?? 'No Email';
    
    // Support both old (pollSelection) and new (pollSelections) formats
    final pollSelections = data['pollSelections'] as List<dynamic>? ?? [];
    String? displaySelections;
    if (pollSelections.isNotEmpty) {
      displaySelections = pollSelections.join(", ");
    } else {
      displaySelections = data['pollSelection'] as String?;
    }

    final textResponse = data['textResponse'] as String?;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant.withAlpha(100)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primary.withAlpha(30),
                    child: Text(name[0].toUpperCase(), style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(email, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (timestamp != null)
                    Text(
                      '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute}',
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                    ),
                ],
              ),
              const Divider(height: 24),
              if (displaySelections != null && displaySelections.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.how_to_vote_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${gu ? 'પસંદગી' : 'Choices'}: $displaySelections',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (textResponse != null && textResponse.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.comment_rounded, size: 16, color: cs.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        textResponse,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => _deleteResponse(docId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteResponse(String docId) async {
    await FirebaseFirestore.instance.collection('announcement_responses').doc(docId).delete();
  }
}
