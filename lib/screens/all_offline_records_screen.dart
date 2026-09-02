import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'pdf_viewer_screen.dart';

class AllOfflineRecordsScreen extends StatefulWidget {
  const AllOfflineRecordsScreen({super.key});

  @override
  State<AllOfflineRecordsScreen> createState() => _AllOfflineRecordsScreenState();
}

class _AllOfflineRecordsScreenState extends State<AllOfflineRecordsScreen> {
  List<String> _savedRecords = [];

  @override
  void initState() {
    super.initState();
    _loadSavedRecords();
  }

  Future<void> _loadSavedRecords() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedRecords = prefs.getStringList('saved_land_records') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.watch<SettingsProvider>().isGujarati;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          gu ? 'તમામ ઓફલાઇન રેકોર્ડ્સ' : 'All Offline Records',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: cs.surfaceContainerLowest,
        foregroundColor: cs.onSurface,
      ),
      body: _savedRecords.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off_rounded, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    gu ? 'કોઈ ઓફલાઇન રેકોર્ડ મળ્યા નથી' : 'No offline records found',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                  )
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _savedRecords.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = _savedRecords[index];
                final parts = record.split('|');
                if (parts.length < 3) return const SizedBox.shrink();

                final path = parts[0];
                final title = parts[1];
                final date = DateTime.tryParse(parts[2]);
                final dateString = date != null ? '${date.day}/${date.month}/${date.year}' : '';

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade400),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(dateString, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade300),
                      onPressed: () async {
                        final file = File(path);
                        if (await file.exists()) {
                          await file.delete();
                        }
                        setState(() {
                          _savedRecords.removeAt(index);
                        });
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setStringList('saved_land_records', _savedRecords);
                      },
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewerScreen(
                            pdfPath: path,
                            title: title,
                            isOfflineRecord: true,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
