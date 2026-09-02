import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String title;
  final bool isOfflineRecord;

  const PdfViewerScreen({
    super.key,
    required this.pdfPath,
    required this.title,
    this.isOfflineRecord = false,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfControllerPinch _pdfController;
  late bool _isDownloaded;

  @override
  void initState() {
    super.initState();
    _isDownloaded = widget.isOfflineRecord;
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(widget.pdfPath),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _sharePdf() async {
    try {
      final file = File(widget.pdfPath);
      final bytes = await file.readAsBytes();
      
      String validFilename = widget.title.replaceAll('/', '_').replaceAll(' ', '_').replaceAll('(', '').replaceAll(')', '');
      await Printing.sharePdf(bytes: bytes, filename: '$validFilename.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share PDF')),
        );
      }
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      String validFilename = widget.title.replaceAll('/', '_').replaceAll(' ', '_').replaceAll('(', '').replaceAll(')', '');
      final fileName = '${validFilename}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final savedFile = File('${docsDir.path}/$fileName');
      
      final tempFile = File(widget.pdfPath);
      await tempFile.copy(savedFile.path);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      List<String> savedRecords = prefs.getStringList('saved_land_records') ?? [];
      
      // Store as "path|title|timestamp"
      final recordData = '${savedFile.path}|${widget.title}|${DateTime.now().toIso8601String()}';
      savedRecords.add(recordData);
      await prefs.setStringList('saved_land_records', savedRecords);

      if (mounted) {
        setState(() {
          _isDownloaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF Downloaded for Offline Access!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        actions: [
          _isDownloaded
              ? IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  tooltip: 'Already Downloaded',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('પહેલેથી જ ડાઉનલોડ કરેલ છે')),
                    );
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Download Offline',
                  onPressed: _downloadPdf,
                ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: _sharePdf,
          ),
        ],
      ),
      body: PdfViewPinch(
        controller: _pdfController,
      ),
    );
  }
}
