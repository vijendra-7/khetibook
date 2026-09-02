import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ScreenshotHelper {
  static Future<void> shareScreenshot({
    required GlobalKey key,
    required String filename,
    String subject = 'KhetiBook',
  }) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)], subject: subject);
    } catch (e) {
      debugPrint('Error sharing screenshot: $e');
    }
  }
}
