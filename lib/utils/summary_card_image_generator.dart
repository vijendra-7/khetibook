import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'gujarati_number_helper.dart';

/// Generates a beautiful shareable card image from data, without taking a screenshot.
class SummaryCardImageGenerator {
  /// Width and height of the generated image (px).
  static const double _w = 1080;
  static const double _h = 540;
  static const double _pad = 64;
  static const double _radius = 40;

  // Cache: once the font is loaded, skip reloading.
  static bool _gujaratiFontLoaded = false;
  static const _kGujaratiFontFamily = 'NotoSansGujarati';

  /// Pre-loads Noto Sans Gujarati into Flutter's font engine so dart:ui canvas
  /// can render Gujarati script correctly (Skia's default font lacks Gujarati).
  static Future<void> _ensureGujaratiFont() async {
    if (_gujaratiFontLoaded) return;
    try {
      // google_fonts caches downloaded fonts to disk. Trigger a load so the
      // bytes are available, then re-register them under our canvas family name.
      final descriptor = GoogleFonts.notoSansGujarati();
      final loader = FontLoader(_kGujaratiFontFamily);

      // Read bytes from google_fonts cache directory
      final cacheDir = await getTemporaryDirectory();
      final parentDir = cacheDir.parent;
      // google_fonts caches under {cacheDir.parent}/google_fonts/
      final fontDir = Directory('${parentDir.path}/google_fonts');
      if (await fontDir.exists()) {
        final files = fontDir.listSync().whereType<File>().toList();
        for (final f in files) {
          if (f.path.toLowerCase().contains('notosansgujarati')) {
            final bytes = await f.readAsBytes();
            loader.addFont(Future.value(ByteData.sublistView(bytes)));
            break;
          }
        }
        await loader.load();
        _gujaratiFontLoaded = true;
        debugPrint('NotoSansGujarati registered for canvas rendering');
      } else {
        // Fallback: use flutter/services rootBundle if font was bundled in assets
        debugPrint('google_fonts cache not found; Gujarati will use system fallback');
      }
      // keep descriptor referenced to suppress unused warning
      debugPrint('google_fonts descriptor: ${descriptor.fontFamily}');
    } catch (e) {
      debugPrint('Font pre-load error (Gujarati images may use system fallback): $e');
    }
  }

  /// Draws rounded rectangle background gradient.
  static void _drawBackground(
      ui.Canvas canvas, Color startColor, Color endColor) {
    const rect = Rect.fromLTWH(0, 0, _w, _h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(_radius));
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(_w, _h),
        [startColor, endColor],
      );
    canvas.drawRRect(rrect, paint);

    // Subtle inner glow ring
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withAlpha(60);
    canvas.drawRRect(rrect, borderPaint);

    // Light decorative circle top-right
    final circlePaint = Paint()
      ..color = Colors.white.withAlpha(20);
    canvas.drawCircle(const Offset(_w - _pad + 20, -60), 220, circlePaint);
    canvas.drawCircle(const Offset(_w - _pad + 80, _h * 0.8), 140, circlePaint);
  }

  /// Draws a single text span on canvas.
  static void _drawText(
    ui.Canvas canvas,
    String text,
    double x,
    double y,
    double fontSize,
    Color color, {
    FontWeight weight = FontWeight.normal,
    TextAlign align = TextAlign.left,
    double maxWidth = _w - 2 * _pad,
    double? lineHeight,
    String? fontFamily,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: align,
      fontSize: fontSize,
      fontWeight: weight,
      height: lineHeight,
      fontFamily: fontFamily,
    ))
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        fontFamily: fontFamily,
      ))
      ..addText(text);
    final para = builder.build();
    para.layout(ui.ParagraphConstraints(width: maxWidth));
    canvas.drawParagraph(para, Offset(x, y));
  }

  /// Row key-value pair.
  static void _drawRow(
    ui.Canvas canvas,
    String label,
    String value,
    double y,
    Color labelColor,
    Color valueColor,
  ) {
    _drawText(canvas, label, _pad, y, 30, labelColor, weight: FontWeight.w500);
    _drawText(canvas, value, _pad, y, 30, valueColor,
        weight: FontWeight.bold,
        align: TextAlign.right,
        maxWidth: _w - 2 * _pad);
  }

  /// Thin divider.
  static void _drawDivider(ui.Canvas canvas, double y, Color color) {
    final paint = Paint()
      ..color = color.withAlpha(80)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(_pad, y), Offset(_w - _pad, y), paint);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates an Investment summary card image and shares it.
  static Future<void> shareInvestmentSummary({
    required String cropName,
    required double total,
    required int count,
    required bool isGujarati,
    required String formattedTotal,
  }) async {
    if (isGujarati) await _ensureGujaratiFont();
    final ff = isGujarati ? _kGujaratiFontFamily : null;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    const startColor = Color(0xFF1A237E);
    const endColor = Color(0xFF283593);
    _drawBackground(canvas, startColor, endColor);

    const white = Colors.white;
    final whiteLight = Colors.white.withAlpha(180);

    _drawText(canvas, isGujarati ? '🌾 ખેતીબુક' : '🌾 KhetiBook',
        _pad, _pad - 10, 28, whiteLight, fontFamily: ff);

    _drawText(canvas, isGujarati ? 'ખર્ચો નો સારાંશ' : 'Investment Summary',
        _pad, _pad + 36, 42, white, weight: FontWeight.bold, fontFamily: ff);

    _drawText(canvas, cropName, _pad, _pad + 96, 34, whiteLight,
        weight: FontWeight.w600, fontFamily: ff);

    _drawDivider(canvas, _h / 2 - 20, white);

    _drawText(canvas, formattedTotal, _pad, _h / 2 + 4, 72, white,
        weight: FontWeight.bold, fontFamily: ff);

    _drawDivider(canvas, _h / 2 + 100, white);

    final countLabel = isGujarati
        ? 'કુલ ${GujaratiNumberHelper.toGujaratiInt(count)} નોંધ'
        : 'Total $count ${count == 1 ? "entry" : "entries"}';
    _drawText(canvas, countLabel, _pad, _h / 2 + 116, 28, whiteLight, fontFamily: ff);

    await _finishAndShare(recorder, 'investment_summary', isGujarati);
  }

  /// Captures a [RepaintBoundary] identified by [key] and shares it as an image.
  static Future<void> shareScreenshot(GlobalKey key, {bool isGujarati = false}) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/summary_share.png');
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: isGujarati ? 'ખેતીબુક' : 'KhetiBook',
      );
    } catch (e) {
      debugPrint('SummaryCardImageGenerator screenshot error: $e');
    }
  }

  /// Generates a Harvest summary card image and shares it.
  static Future<void> shareHarvestSummary({
    required String cropName,
    required double totalRevenue,
    required int count,
    required bool isGujarati,
    required String formattedRevenue,
  }) async {
    if (isGujarati) await _ensureGujaratiFont();
    final ff = isGujarati ? _kGujaratiFontFamily : null;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    const startColor = Color(0xFF1B5E20);
    const endColor = Color(0xFF2E7D32);
    _drawBackground(canvas, startColor, endColor);

    const white = Colors.white;
    final whiteLight = Colors.white.withAlpha(180);

    _drawText(canvas, isGujarati ? '🌾 ખેતીબુક' : '🌾 KhetiBook',
        _pad, _pad - 10, 28, whiteLight, fontFamily: ff);

    _drawText(canvas, isGujarati ? 'ઉત્પાદન નો સારાંશ' : 'Harvest Summary',
        _pad, _pad + 36, 42, white, weight: FontWeight.bold, fontFamily: ff);

    _drawText(canvas, cropName, _pad, _pad + 96, 34, whiteLight,
        weight: FontWeight.w600, fontFamily: ff);

    _drawDivider(canvas, _h / 2 - 20, white);

    _drawText(canvas, formattedRevenue, _pad, _h / 2 + 4, 72, white,
        weight: FontWeight.bold, fontFamily: ff);

    _drawDivider(canvas, _h / 2 + 100, white);

    final countLabel = isGujarati
        ? 'કુલ ${GujaratiNumberHelper.toGujaratiInt(count)} ઉત્પાદન'
        : 'Total $count ${count == 1 ? "harvest" : "harvests"}';
    _drawText(canvas, countLabel, _pad, _h / 2 + 116, 28, whiteLight, fontFamily: ff);

    await _finishAndShare(recorder, 'harvest_summary', isGujarati);
  }

  /// Generates a Helper Account summary card image and shares it.
  static Future<void> shareHelperSummary({
    required String typeName,
    required double total,
    required int count,
    required bool isGujarati,
    required String formattedTotal,
  }) async {
    if (isGujarati) await _ensureGujaratiFont();
    final ff = isGujarati ? _kGujaratiFontFamily : null;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    const startColor = Color(0xFF4A148C);
    const endColor = Color(0xFF6A1B9A);
    _drawBackground(canvas, startColor, endColor);

    const white = Colors.white;
    final whiteLight = Colors.white.withAlpha(180);

    _drawText(canvas, isGujarati ? '🌾 ખેતીબુક' : '🌾 KhetiBook',
        _pad, _pad - 10, 28, whiteLight, fontFamily: ff);

    _drawText(canvas, isGujarati ? 'સહાયક ખર્ચ નો સારાંશ' : 'Helper Expense Summary',
        _pad, _pad + 36, 42, white, weight: FontWeight.bold, fontFamily: ff);

    _drawText(canvas, typeName, _pad, _pad + 96, 34, whiteLight,
        weight: FontWeight.w600, fontFamily: ff);

    _drawDivider(canvas, _h / 2 - 20, white);

    _drawText(canvas, formattedTotal, _pad, _h / 2 + 4, 72, white,
        weight: FontWeight.bold, fontFamily: ff);

    _drawDivider(canvas, _h / 2 + 100, white);

    final countLabel = isGujarati
        ? 'કુલ ${GujaratiNumberHelper.toGujaratiInt(count)} વ્યવહાર'
        : 'Total $count ${count == 1 ? "transaction" : "transactions"}';
    _drawText(canvas, countLabel, _pad, _h / 2 + 116, 28, whiteLight, fontFamily: ff);

    await _finishAndShare(recorder, 'helper_summary', isGujarati);
  }

  /// Generates an Investment *entry detail* card image and shares it.
  static Future<void> shareInvestmentEntry({
    required String cropName,
    required String typeName,
    required String dateStr,
    required double totalAmount,
    required bool isGujarati,
    required String formattedTotal,
    String? seedType,
    String? kataQty,
    String? pricePerKata,
    String? vigha,
    String? cost,
    String? serviceProvider,
    String? paymentStatus,
    String? pendingAmount,
    String? panchang,
  }) async {
    if (isGujarati) await _ensureGujaratiFont();
    final ff = isGujarati ? _kGujaratiFontFamily : null;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    const cardW = 1080.0;
    const headerH = 260.0;
    const rowH = 64.0;

    // Collect rows
    final rows = <(String, String)>[];
    if (isGujarati) {
      rows.add(('\u0aaa\u0acd\u0ab0\u0a95\u0abe\u0ab0', typeName));
      if (seedType != null && seedType.isNotEmpty) rows.add(('\u0aac\u0ac0\u0a9c', seedType));
      if (kataQty != null && kataQty.isNotEmpty) rows.add(('\u0a95\u0acd\u0ab5\u0acb\u0aa8\u0acd\u0a9f\u0abf\u0a9f\u0ac0', kataQty));
      if (pricePerKata != null && pricePerKata.isNotEmpty) rows.add(('\u0aad\u0abe\u0ab5/\u0a95\u0a9f\u0acd\u0a9f\u0acb', pricePerKata));
      if (vigha != null && vigha.isNotEmpty) rows.add(('\u0ab5\u0abf\u0a98\u0abe', vigha));
      if (cost != null && cost.isNotEmpty) rows.add(('\u0a96\u0ab0\u0acd\u0a9a', cost));
      if (serviceProvider != null && serviceProvider.isNotEmpty) rows.add(('\u0ab8\u0acd\u0ab0\u0acb\u0aa4', serviceProvider));
      if (paymentStatus != null) rows.add(('\u0a9a\u0ac2\u0a95\u0ab5\u0aa3\u0ac0', paymentStatus));
      if (pendingAmount != null && pendingAmount.isNotEmpty) rows.add(('\u0aac\u0abe\u0a95\u0ac0 \u0ab0\u0a95\u0aae', pendingAmount));
      if (vigha != null && vigha.contains(':')) {
        final parts = vigha.split('|');
        for (final p in parts) {
          if (p.contains(':')) {
            final dp = p.split(':');
            rows.add(('', '${dp[0]} : ${dp[1]}'));
          }
        }
      }
      rows.add(('\u0aa4\u0abe\u0ab0\u0ac0\u0a96', dateStr));
      if (panchang != null && panchang.isNotEmpty) rows.add(('\ud83c\udf19', panchang));
    } else {
      rows.add(('Type', typeName));
      if (seedType != null && seedType.isNotEmpty) rows.add(('Seed', seedType));
      if (kataQty != null && kataQty.isNotEmpty) rows.add(('Quantity', kataQty));
      if (pricePerKata != null && pricePerKata.isNotEmpty) rows.add(('Price/Kata', pricePerKata));
      if (vigha != null && vigha.isNotEmpty) rows.add(('Vigha', vigha));
      if (cost != null && cost.isNotEmpty) rows.add(('Cost', cost));
      if (serviceProvider != null && serviceProvider.isNotEmpty) rows.add(('Provider', serviceProvider));
      if (paymentStatus != null) rows.add(('Payment', paymentStatus));
      if (pendingAmount != null && pendingAmount.isNotEmpty) rows.add(('Amount Due', pendingAmount));
      if (vigha != null && vigha.contains(':')) {
        final parts = vigha.split('|');
        for (final p in parts) {
          if (p.contains(':')) {
            final dp = p.split(':');
            rows.add(('', '${dp[0]} : ${dp[1]}'));
          }
        }
      }
      rows.add(('Date', dateStr));
      if (panchang != null && panchang.isNotEmpty) rows.add(('\ud83c\udf19', panchang));
    }

    final cardH = headerH + rows.length * rowH + 80;

    // Full-height gradient background
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(cardW, cardH),
        [const Color(0xFF1A237E), const Color(0xFF283593)],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, cardW, cardH), const Radius.circular(40)),
      bgPaint,
    );
    canvas.drawCircle(const Offset(cardW - 40, -60), 220, Paint()..color = Colors.white.withAlpha(20));
    canvas.drawCircle(Offset(cardW - 40 + 80, cardH * 0.8), 140, Paint()..color = Colors.white.withAlpha(15));

    const white = Colors.white;
    final whiteDim = Colors.white.withAlpha(180);

    // Header
    _drawText(canvas, isGujarati ? '\ud83c\udf3e \u0a96\u0ac7\u0aa4\u0ac0\u0aac\u0ac1\u0a95' : '\ud83c\udf3e KhetiBook',
        _pad, _pad - 10, 28, whiteDim, fontFamily: ff);
    _drawText(canvas, cropName, _pad, _pad + 36, 42, white, weight: FontWeight.bold, fontFamily: ff);
    _drawText(canvas, formattedTotal, _pad, _pad + 96, 68, white, weight: FontWeight.bold, fontFamily: ff);

    _drawDivider(canvas, headerH - 10, white);

    // Detail rows
    double y = headerH + 20;
    for (int i = 0; i < rows.length; i++) {
      final label = rows[i].$1;
      final value = rows[i].$2;
      final isLast = i == rows.length - 1;
      _drawText(canvas, label, _pad, y, 28, whiteDim, fontFamily: ff);
      _drawText(canvas, value, _pad, y, 28, white,
          weight: isLast ? FontWeight.w600 : FontWeight.w500,
          align: TextAlign.right,
          maxWidth: cardW - 2 * _pad,
          fontFamily: ff);
      if (!isLast) _drawDivider(canvas, y + rowH - 4, white);
      y += rowH;
    }

    await _finishAndShareCustomSize(recorder, 'investment_detail', isGujarati, cardW.toInt(), cardH.toInt());
  }

  static Future<void> shareHarvestEntry({
    required String cropName,
    required String dateStr,
    required bool isGujarati,
    required String formattedRevenue,
    String? field,
    String? bharati,
    String? remainingKg,
    String? pricePer20kg,
    String? soldTo,
  }) async {
    if (isGujarati) await _ensureGujaratiFont();
    final ff = isGujarati ? _kGujaratiFontFamily : null;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    const cardW = 1080.0;
    const headerH = 260.0;
    const rowH = 64.0;

    final rows = <(String, String)>[];
    if (isGujarati) {
      if (field != null && field.isNotEmpty) rows.add(('ખેતર', field));
      if (cropName != 'Tarbuch') {
        final bLabel = (cropName == 'Bataka') ? 'ભરતી (82kg)' : (cropName == 'Bajari' || cropName == 'Ghau' ? 'ભરતી (100kg)' : 'ભરતી (34kg)');
        if (bharati != null && bharati.isNotEmpty) rows.add((bLabel, bharati));
      }
      final rLabel = (cropName == 'Tarbuch') ? 'વજન (Kg)' : 'ઉપરના (Kg)';
      if (remainingKg != null && remainingKg.isNotEmpty) rows.add((rLabel, remainingKg));
      
      final pLabel = (cropName == 'Tarbuch') ? 'ભાવ (Kg)' : 'ભાવ (20 Kg)';
      if (pricePer20kg != null && pricePer20kg.isNotEmpty) rows.add((pLabel, pricePer20kg));
      
      if (soldTo != null && soldTo.isNotEmpty) rows.add(('વેપારી', soldTo));
      rows.add(('તારીખ', dateStr));
    } else {
      if (field != null && field.isNotEmpty) rows.add(('Field/Location', field));
      if (cropName != 'Tarbuch') {
        final bLabel = (cropName == 'Bataka') ? 'Bharati (82kg)' : (cropName == 'Bajari' || cropName == 'Ghau' ? 'Bharati (100kg)' : 'Bharati (34kg)');
        if (bharati != null && bharati.isNotEmpty) rows.add((bLabel, bharati));
      }
      final rLabel = (cropName == 'Tarbuch') ? 'Weight (kg)' : 'Remaining (kg)';
      if (remainingKg != null && remainingKg.isNotEmpty) rows.add((rLabel, remainingKg));
      
      final pLabel = (cropName == 'Tarbuch') ? 'Price/kg' : 'Price (20 Kg)';
      if (pricePer20kg != null && pricePer20kg.isNotEmpty) rows.add((pLabel, pricePer20kg));
      
      if (soldTo != null && soldTo.isNotEmpty) rows.add(('Sold To', soldTo));
      rows.add(('Date', dateStr));
    }

    final cardH = headerH + rows.length * rowH + 80;

    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(cardW, cardH),
        [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
      );
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, cardW, cardH), const Radius.circular(40)), bgPaint);
    canvas.drawCircle(const Offset(cardW - 40, -60), 220, Paint()..color = Colors.white.withAlpha(20));
    canvas.drawCircle(Offset(cardW - 40 + 80, cardH * 0.8), 140, Paint()..color = Colors.white.withAlpha(15));

    const white = Colors.white;
    final whiteDim = Colors.white.withAlpha(180);

    // Header
    _drawText(canvas, isGujarati ? '🌾 ખેતીબુક' : '🌾 KhetiBook', _pad, _pad - 10, 28, whiteDim, fontFamily: ff);
    _drawText(canvas, cropName, _pad, _pad + 36, 42, white, weight: FontWeight.bold, fontFamily: ff);
    _drawText(canvas, formattedRevenue, _pad, _pad + 96, 68, white, weight: FontWeight.bold, fontFamily: ff);

    _drawDivider(canvas, headerH - 10, white);

    double y = headerH + 20;
    for (int i = 0; i < rows.length; i++) {
      final isLast = i == rows.length - 1;
      _drawText(canvas, rows[i].$1, _pad, y, 28, whiteDim, fontFamily: ff);
      _drawText(canvas, rows[i].$2, _pad, y, 28, white, weight: isLast ? FontWeight.w600 : FontWeight.w500, align: TextAlign.right, maxWidth: cardW - 2 * _pad, fontFamily: ff);
      if (!isLast) _drawDivider(canvas, y + rowH - 4, white);
      y += rowH;
    }

    await _finishAndShareCustomSize(recorder, 'harvest_detail', isGujarati, cardW.toInt(), cardH.toInt());
  }

  static Future<void> shareHelperEntry({
    required String typeName,
    required String dateStr,
    required bool isGujarati,
    required String formattedTotal,
    String? helperName,
    String? workerCount,
    String? amountPerWorker,
    String? field,
    String? equipmentType,
    String? hours,
    String? pricePerHour,
  }) async {
    if (isGujarati) await _ensureGujaratiFont();
    final ff = isGujarati ? _kGujaratiFontFamily : null;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    const cardW = 1080.0;
    const headerH = 260.0;
    const rowH = 64.0;

    final rows = <(String, String)>[];
    if (isGujarati) {
      if (helperName != null && helperName.isNotEmpty) rows.add(('નામ', helperName));
      if (workerCount != null && workerCount.isNotEmpty) rows.add(('મજૂરો', workerCount));
      if (amountPerWorker != null && amountPerWorker.isNotEmpty) rows.add(('મજૂરી/વ્યક્તિ', amountPerWorker));
      if (field != null && field.isNotEmpty) rows.add(('ખેતર', field));
      if (equipmentType != null && equipmentType.isNotEmpty) rows.add(('સાધન', equipmentType));
      if (hours != null && hours.isNotEmpty) rows.add(('કલાક', hours));
      if (pricePerHour != null && pricePerHour.isNotEmpty) rows.add(('ભાવ/કલાક', pricePerHour));
      rows.add(('તારીખ', dateStr));
    } else {
      if (helperName != null && helperName.isNotEmpty) rows.add(('Name', helperName));
      if (workerCount != null && workerCount.isNotEmpty) rows.add(('Workers', workerCount));
      if (amountPerWorker != null && amountPerWorker.isNotEmpty) rows.add(('Per Worker', amountPerWorker));
      if (field != null && field.isNotEmpty) rows.add(('Field/Location', field));
      if (equipmentType != null && equipmentType.isNotEmpty) rows.add(('Equipment', equipmentType));
      if (hours != null && hours.isNotEmpty) rows.add(('Hours', hours));
      if (pricePerHour != null && pricePerHour.isNotEmpty) rows.add(('Price/Hr', pricePerHour));
      rows.add(('Date', dateStr));
    }

    final cardH = headerH + rows.length * rowH + 80;

    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(cardW, cardH),
        [const Color(0xFF4A148C), const Color(0xFF6A1B9A)],
      );
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, cardW, cardH), const Radius.circular(40)), bgPaint);
    canvas.drawCircle(const Offset(cardW - 40, -60), 220, Paint()..color = Colors.white.withAlpha(20));
    canvas.drawCircle(Offset(cardW - 40 + 80, cardH * 0.8), 140, Paint()..color = Colors.white.withAlpha(15));

    const white = Colors.white;
    final whiteDim = Colors.white.withAlpha(180);

    // Header
    _drawText(canvas, isGujarati ? '🌾 ખેતીબુક' : '🌾 KhetiBook', _pad, _pad - 10, 28, whiteDim, fontFamily: ff);
    _drawText(canvas, typeName, _pad, _pad + 36, 42, white, weight: FontWeight.bold, fontFamily: ff);
    _drawText(canvas, formattedTotal, _pad, _pad + 96, 68, white, weight: FontWeight.bold, fontFamily: ff);

    _drawDivider(canvas, headerH - 10, white);

    double y = headerH + 20;
    for (int i = 0; i < rows.length; i++) {
      final isLast = i == rows.length - 1;
      _drawText(canvas, rows[i].$1, _pad, y, 28, whiteDim, fontFamily: ff);
      _drawText(canvas, rows[i].$2, _pad, y, 28, white, weight: isLast ? FontWeight.w600 : FontWeight.w500, align: TextAlign.right, maxWidth: cardW - 2 * _pad, fontFamily: ff);
      if (!isLast) _drawDivider(canvas, y + rowH - 4, white);
      y += rowH;
    }

    await _finishAndShareCustomSize(recorder, 'helper_detail', isGujarati, cardW.toInt(), cardH.toInt());
  }

  static Future<void> _finishAndShareCustomSize(
      ui.PictureRecorder recorder, String filename, bool isGujarati, int w, int h) async {
    try {
      final picture = recorder.endRecording();
      final image = await picture.toImage(w, h);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: isGujarati ? '\u0a96\u0ac7\u0aa4\u0ac0\u0aac\u0ac1\u0a95' : 'KhetiBook',
      );
    } catch (e) {
      debugPrint('SummaryCardImageGenerator error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INTERNAL
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _finishAndShare(
      ui.PictureRecorder recorder, String filename, bool isGujarati) async {
    try {
      final picture = recorder.endRecording();
      final image = await picture.toImage(_w.toInt(), _h.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: isGujarati ? 'ખેતીબુક' : 'KhetiBook',
      );
    } catch (e) {
      debugPrint('SummaryCardImageGenerator error: $e');
    }
  }
}
