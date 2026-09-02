import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdfx/pdfx.dart' as px;
import 'package:screenshot/screenshot.dart';
import '../database/app_database.dart';
import '../models/statement_entry.dart';
import '../providers/settings_provider.dart';
import '../utils/language_mapper.dart';
import '../utils/custom_options_manager.dart';
import '../utils/gujarati_number_helper.dart';
import '../widgets/statement_receipt_widget.dart';
import '../widgets/premium_select.dart';
import '../providers/global_options_provider.dart';

class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key});

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  String? _selectedCrop; // null = 'All'
  int _selectedYear = DateTime.now().year;
  List<StatementEntry> _entries = [];
  bool _loading = false;
  bool _generated = false;
  List<String> _crops = [];
  String? _selectedField; // null = 'All'
  List<String> _fieldOptions = [];
  bool _isPreparingPdf = false;
  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _loadOptions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seenStatementOverlay') ?? false;
    if (!seen && mounted) {
      _showOnboardingOverlay();
      await prefs.setBool('seenStatementOverlay', true);
    }
  }

  void _showOnboardingOverlay() {
    final gu = context.read<SettingsProvider>().isGujarati;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_balance_wallet_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              gu ? 'ખેતી સ્ટેટમેન્ટ' : 'Farming Statement',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              gu 
                ? 'આ સ્ટેટમેન્ટમાં તમારી ખેતીના બધા ખર્ચ અને આવકનો હિસાબ એક જગ્યાએ જોવા મળશે, બિલકુલ બેંકના સ્ટેટમેન્ટ જેમ.'
                : 'In this statement, you will see all your farming expenses and income in one place, just like a bank statement.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(gu ? 'સમજાયું' : 'Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadOptions() async {
    final crops = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categorysCrops);
    
    // Get fields from multiple sources
    final customFields = await CustomOptionsManager.getAllOptions('fields');
    final dbFields1 = await AppDatabase.instance.getUniqueValues('investments', 'fieldName');
    final dbFields2 = await AppDatabase.instance.getUniqueValues('outputs', 'field');
    final dbFields3 = await AppDatabase.instance.getUniqueValues('helper_transactions', 'field');
    
    final allFields = <String>{...customFields, ...dbFields1, ...dbFields2, ...dbFields3};
    allFields.removeWhere((s) => s.isEmpty);
    
    if (mounted) {
      setState(() {
        _crops = crops;
        if (_selectedCrop == null && _crops.isNotEmpty) {
          _selectedCrop = _crops.first;
        }
        _fieldOptions = allFields.toList()..sort();
      });
    }
  }

  (int, int) _dateRange(String? crop, int year) {
    if (crop == null) {
      final start = DateTime(year, 1, 1).millisecondsSinceEpoch;
      final end = DateTime(year, 12, 31, 23, 59, 59).millisecondsSinceEpoch;
      return (start, end);
    }
    // Bataka/Ghau: Oct-Apr season
    final octStart = ['Bataka', 'Ghau'].contains(crop);
    if (octStart) {
      final start = DateTime(year - 1, 10, 1).millisecondsSinceEpoch;
      final end = DateTime(year, 4, 30, 23, 59, 59).millisecondsSinceEpoch;
      return (start, end);
    }
    final start = DateTime(year, 1, 1).millisecondsSinceEpoch;
    final end = DateTime(year, 12, 31, 23, 59, 59).millisecondsSinceEpoch;
    return (start, end);
  }

  Future<void> _generate() async {
    final gu = context.read<SettingsProvider>().isGujarati;
    setState(() { _loading = true; _entries = []; });
    final (start, end) = _dateRange(_selectedCrop, _selectedYear);
    final investments = await AppDatabase.instance.getInvestmentsByCropAndYear(_selectedCrop, start, end);
    final outputs = await AppDatabase.instance.getOutputsByCropAndYear(_selectedCrop, start, end);

    final List<StatementEntry> entries = [];

    for (final inv in investments) {
      if (_selectedField != null && inv.fieldName != _selectedField) continue;

      final crop = inv.crop;
      final seedLoc = LanguageMapper.localizedSeedForCrop(crop, inv.seedType, gu);
      String desc = inv.investmentType == 'Biyaran'
          ? '$seedLoc – ${gu ? GujaratiNumberHelper.toGujaratiInt(inv.kataQuantity.toInt()) : inv.kataQuantity.toInt()} ${LanguageMapper.localizedQuantityUnit(crop, gu)} @ ${GujaratiNumberHelper.formatCurrency(inv.pricePerKata, gujarati: gu)}'
          : LanguageMapper.localizedInvestmentType(inv.displayInvestmentType, gu);
      
      final extras = [];
      if (inv.biyaranCompany.isNotEmpty) extras.add(inv.biyaranCompany);
      if (inv.fieldName.isNotEmpty) extras.add(inv.fieldName);
      if (inv.vigha.isNotEmpty && !inv.vigha.contains(':')) extras.add(inv.vigha);
      if (_selectedCrop == null) extras.add(LanguageMapper.localizedCrop(crop, gu));
      if (extras.isNotEmpty) desc += ' (${extras.join(', ')})';

      entries.add(StatementEntry(
        date: inv.date,
        type: gu ? 'ખર્ચો' : 'Investment',
        description: desc,
        amount: inv.totalAmount,
        crop: inv.crop,
        field: inv.fieldName,
      ));
    }

    for (final out in outputs) {
      if (_selectedField != null && out.field != _selectedField) continue;

      final crop = out.crop;
      final priceUnit = crop == 'Tarbuch' ? (gu ? 'kg' : 'kg') : (gu ? '20kg' : '20kg');
      String desc = gu 
          ? 'ભરતી ${GujaratiNumberHelper.toGujaratiInt(out.bharati)} @ ${GujaratiNumberHelper.formatCurrency(out.pricePer20kg, gujarati: true)}/$priceUnit' 
          : 'Bharati ${out.bharati} @ ₹${out.pricePer20kg.toInt()}/$priceUnit';
      
      final extras = [];
      if (out.field.isNotEmpty) extras.add(out.field);
      if (out.vigha.isNotEmpty) extras.add(out.vigha);
      if (_selectedCrop == null) extras.add(LanguageMapper.localizedCrop(crop, gu));
      if (extras.isNotEmpty) desc += ' (${extras.join(', ')})';

      entries.add(StatementEntry(
        date: out.date,
        type: gu ? 'ઉત્પાદન' : 'Harvest',
        description: desc,
        amount: out.revenue,
        crop: out.crop,
        field: out.field,
      ));
    }

    for (final type in ['Majur', 'Bhaag', 'Upaad']) {
      final txns = await AppDatabase.instance.getTransactionsByTypeAndYear(type, start, end);
      final locType = LanguageMapper.localizedTransactionType(type, gu);
      for (final txn in txns) {
        // Filter crop-specific types
        if (type == 'Majur' || type == 'Bhaag') {
          if (_selectedCrop != null && txn.crop != _selectedCrop) continue;
        } else if (type == 'Upaad') {
          // Upaad is non-crop specific, so exclude if a specific crop is filtered
          if (_selectedCrop != null) continue;
        }

        if (_selectedField != null && txn.field != _selectedField) continue;

        final locHelper = LanguageMapper.localizedServiceProvider(txn.helperName, gu);
        String desc = type == 'Majur'
            ? '$locHelper – ${gu ? GujaratiNumberHelper.toGujaratiInt(txn.workerCount) : txn.workerCount} ${gu ? 'મજૂરો' : 'workers'} @ ${GujaratiNumberHelper.formatCurrency(txn.amountPerWorker, gujarati: gu)}'
            : '$locHelper – ${GujaratiNumberHelper.formatCurrency(txn.amount, gujarati: gu)}';
        
        final extras = [];
        if (type != 'Upaad') {
          if (txn.field.isNotEmpty) extras.add(txn.field);
          if (txn.vigha.isNotEmpty) extras.add(txn.vigha);
        }
        if (_selectedCrop == null && txn.crop.isNotEmpty) extras.add(LanguageMapper.localizedCrop(txn.crop, gu, context.read<GlobalOptionsProvider>().getGlobalCropMap(gu)));
        if (extras.isNotEmpty) desc += ' (${extras.join(', ')})';

        entries.add(StatementEntry(
          date: txn.date,
          type: locType,
          description: desc,
          amount: txn.totalAmount,
          crop: txn.crop,
          field: txn.field,
        ));
      }
    }

    entries.sort((a, b) => a.date.compareTo(b.date));
    if (mounted) setState(() { _entries = entries; _loading = false; _generated = true; });
  }

  double get _totalInvestment => _entries.where((e) => e.type == 'Investment' || e.type == 'ખર્ચો').fold(0, (s, e) => s + e.amount);
  double get _totalHarvest => _entries.where((e) => e.type == 'Harvest' || e.type == 'ઉત્પાદન').fold(0, (s, e) => s + e.amount);
  double get _totalHelpers => _entries.where((e) => e.type != 'Investment' && e.type != 'Harvest' && e.type != 'ખર્ચો' && e.type != 'ઉત્પાદન').fold(0, (s, e) => s + e.amount);
  double get _totalExpenses => _totalInvestment + _totalHelpers;
  double get _netProfit => _totalHarvest - _totalExpenses;

  @override
  Widget build(BuildContext context) {
    final gu = context.watch<SettingsProvider>().isGujarati;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(gu ? 'નાણાકીય સ્ટેટમેન્ટ' : 'Financial Statement'),
        actions: [
          if (_generated && _entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: () => _exportPdf(gu, isPrint: true),
              tooltip: gu ? 'PDF નિકાસ' : 'Export PDF',
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
              _buildInfoCard(gu, cs), // Added the informational card here
              // Filter card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(gu ? 'ફિલ્ટર' : 'Filter', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: PremiumSelect(
                          label: gu ? 'પાક' : 'Crop',
                          value: _selectedCrop == null ? (gu ? 'બધા પાક' : 'All Crops') : LanguageMapper.localizedCrop(_selectedCrop!, gu, context.read<GlobalOptionsProvider>().getGlobalCropMap(gu)),
                          items: [
                            gu ? 'બધા પાક' : 'All Crops',
                            ..._crops.map((c) => LanguageMapper.localizedCrop(c, gu, context.read<GlobalOptionsProvider>().getGlobalCropMap(gu))),
                          ],
                          hint: gu ? 'પાક પસંદ કરો' : 'Select crop',
                          isGujarati: gu,
                          icon: Icons.grass_rounded,
                          onChanged: (v) {
                            setState(() {
                              if (v == (gu ? 'બધા પાક' : 'All Crops')) {
                                _selectedCrop = null;
                              } else {
                                _selectedCrop = LanguageMapper.englishCrop(v, gu);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PremiumSelect(
                          label: gu ? 'વર્ષ' : 'Year',
                          value: gu ? GujaratiNumberHelper.toGujaratiInt(_selectedYear) : _selectedYear.toString(),
                          items: List.generate(10, (i) => DateTime.now().year - 4 + i)
                              .map((y) => gu ? GujaratiNumberHelper.toGujaratiInt(y) : y.toString())
                              .toList(),
                          hint: gu ? 'વર્ષ પસંદ કરો' : 'Select year',
                          isGujarati: gu,
                          icon: Icons.calendar_today_rounded,
                          onChanged: (v) {
                            setState(() {
                              _selectedYear = int.tryParse(gu ? GujaratiNumberHelper.toEnglishInt(v) : v) ?? _selectedYear;
                            });
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    PremiumSelect(
                      label: gu ? 'ખેતર' : 'Field Name',
                      value: _selectedField ?? (gu ? 'બધા ખેતર' : 'All Fields'),
                      items: [
                        gu ? 'બધા ખેતર' : 'All Fields',
                        ..._fieldOptions,
                      ],
                      hint: gu ? 'ખેતર પસંદ કરો' : 'Select field',
                      isGujarati: gu,
                      icon: Icons.landscape_rounded,
                      onChanged: (v) {
                        setState(() {
                          if (v == (gu ? 'બધા ખેતર' : 'All Fields')) {
                            _selectedField = null;
                          } else {
                            _selectedField = v;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _generate,
                        icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh_rounded),
                        label: Text(gu ? 'જનરેટ' : 'Generate'),
                      ),
                    ),
                  ]),
                ),
              ),
              if (_generated && _entries.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cs.primary.withAlpha(80)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerPage(
                            onBuild: (format) => _exportPdf(gu, format: format, showProgress: false),
                                title: gu 
                                    ? 'ચોપડો - ${LanguageMapper.localizedCrop(_selectedCrop ?? (gu ? "બધા પાક" : "All Crops"), gu)}' 
                                    : 'Statement - ${LanguageMapper.localizedCrop(_selectedCrop ?? (gu ? "બધા પાક" : "All Crops"), gu)}',
                          )));
                        },
                        icon: Icon(Icons.visibility_outlined, size: 18, color: cs.primary),
                        label: Text(gu ? 'PDF જુઓ' : 'View PDF', style: TextStyle(color: cs.primary)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cs.primary.withAlpha(80)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          final bytes = await _exportPdf(gu);
                          if (bytes != null) {
                            final cropName = _selectedCrop ?? (gu ? 'બધા_પાક' : 'All_Crops');
                            final filename = gu ? 'ચોપડો_${cropName}_$_selectedYear.pdf' : 'Statement_${cropName}_$_selectedYear.pdf';
                            await Printing.sharePdf(bytes: bytes, filename: filename);
                          }
                        },
                        icon: Icon(Icons.share_rounded, size: 18, color: cs.primary),
                        label: Text(gu ? 'શેર PDF' : 'Share PDF', style: TextStyle(color: cs.primary)),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(children: [
                    Expanded(child: _SummaryChip(label: gu ? 'ખર્ચ' : 'Expenses', amount: _totalExpenses, color: cs.error)),
                    const SizedBox(width: 8),
                    Expanded(child: _SummaryChip(label: gu ? 'ઉત્પાદન' : 'Harvest', amount: _totalHarvest, color: Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _SummaryChip(label: gu ? 'નફો' : 'Profit', amount: _netProfit, color: _netProfit >= 0 ? Colors.green : cs.error, bold: true)),
                  ]),
                ),
              ],
              _loading
                    ? const Center(child: CircularProgressIndicator())
                    : !_generated
                        ? Center(child: Text(gu ? 'જનરેટ દબાવો' : 'Press Generate', style: TextStyle(color: cs.outline)))
                        : Column(
                            children: [
                              _buildTableHeader(gu, cs),
                              ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _entries.length,
                                itemBuilder: (_, i) => _EntryRow(
                                  entry: _entries[i],
                                  isGujarati: gu,
                                  showCrop: _selectedCrop == null,
                                  showField: _selectedField == null,
                                ),
                              ),
                            ],
                          ),
              const SizedBox(height: 100), // Extra space for FAB or footer if needed
            ],
          ),
          ),
          if (_isPreparingPdf)
            Container(
              color: Colors.black.withAlpha(100),
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(strokeWidth: 3),
                        const SizedBox(height: 20),
                        Text(
                          gu ? 'PDF પ્રોસેસિંગ...' : 'Preparing PDF...',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          gu ? 'કૃપા કરીને થોડીવાર રાહ જુઓ' : 'Please wait a moment',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<Uint8List?> _exportPdf(bool gu, {bool isPrint = false, PdfPageFormat format = PdfPageFormat.a4, bool showProgress = true}) async {
    if (showProgress) setState(() => _isPreparingPdf = true);
    try {
      if (_logoBytes == null) {
        final data = await rootBundle.load('assets/images/logo.webp');
        _logoBytes = data.buffer.asUint8List();
      }

      final widget = StatementReceiptWidget(
        gu: gu,
        crop: _selectedCrop ?? (gu ? 'બધા પાક' : 'All Crops'),
        year: _selectedYear,
        entries: _entries,
        totalInvestment: _totalInvestment,
        totalHarvest: _totalHarvest,
        netProfit: _netProfit,
        logoBytes: _logoBytes!,
        fieldName: _selectedField,
        showCrop: _selectedCrop == null,
        showField: _selectedField == null,
        globalCropMap: context.read<GlobalOptionsProvider>().getGlobalCropMap(gu),
      );

      final screenshotController = ScreenshotController();
      final imageBytes = await screenshotController.captureFromWidget(
        widget,
        // Force the off-screen surface to be 595 logical units wide
        targetSize: const Size(595, 2000), // Height is ignored if fit: contain but we need a starting point
        pixelRatio: 2.0,
        delay: const Duration(milliseconds: 500),
      );

      final doc = pw.Document();
      final image = pw.MemoryImage(imageBytes);

      // pixelRatio: 2.0, so image is 2× the widget's logical size.
      // Widget is 595 logical px wide → image is 1190 physical px wide.
      // Convert image dimensions back to PDF points (1 pt = 1 logical px here).
      const double pixelRatio = 2.0;
      const double a4W = 595.28;   // A4 width in pt
      const double a4H = 841.89;   // A4 height in pt

      final double imgH  = (image.height ?? 2000).toDouble();
      final double totalH = imgH / pixelRatio; // full content height in points

      final int pageCount = (totalH / a4H).ceil();

      for (int i = 0; i < pageCount; i++) {
        final double yOffset = i * a4H; // points already shown on previous pages
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context ctx) => pw.ClipRect(
              child: pw.Transform(
                // Shift image UP so page i's content aligns with the top of the page
                transform: Matrix4.translationValues(0, -yOffset, 0),
                child: pw.SizedBox(
                  width: a4W,
                  height: totalH,
                  child: pw.Image(image, fit: pw.BoxFit.fitWidth,
                      alignment: pw.Alignment.topLeft),
                ),
              ),
            ),
          ),
        );
      }

      final cropNameForFile = _selectedCrop ?? (gu ? 'બધા_પાક' : 'All_Crops');
      final filename = gu ? 'ચોપડો_${cropNameForFile}_$_selectedYear.pdf' : 'Statement_${cropNameForFile}_$_selectedYear.pdf';
      final bytes = await doc.save();
      
      if (isPrint) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: filename,
        );
      }
      return bytes;
    } catch (e) {
      debugPrint('PDF Export Error: $e');
      return null;
    } finally {
      if (showProgress) setState(() => _isPreparingPdf = false);
    }
  }

  Widget _buildTableHeader(bool gu, ColorScheme cs) {
    final showCrop = _selectedCrop == null;
    final showField = _selectedField == null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(children: [
        SizedBox(width: 36, child: Text(gu ? 'તારીખ' : 'Date', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.primary))),
        const SizedBox(width: 8),
        SizedBox(width: 45, child: Text(gu ? 'પ્રકાર' : 'Type', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.primary))),
        if (showCrop) ...[
          const SizedBox(width: 8),
          SizedBox(width: 50, child: Text(gu ? 'પાક' : 'Crop', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.primary))),
        ],
        if (showField) ...[
          const SizedBox(width: 8),
          SizedBox(width: 50, child: Text(gu ? 'ખેતર' : 'Field', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.primary))),
        ],
        const SizedBox(width: 8),
        Expanded(child: Text(gu ? 'વિગત' : 'Description', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.primary))),
        Text(gu ? 'રકમ' : 'Amount', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.primary)),
      ]),
    );
  }

  Widget _buildInfoCard(bool gu, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              gu 
                ? 'આ સ્ટેટમેન્ટમાં તમારી ખેતીના બધા ખર્ચ અને આવકનો હિસાબ એક જગ્યાએ જોવા મળશે, બિલકુલ બેંકના સ્ટેટમેન્ટ જેમ.'
                : 'In this statement, you will see all your farming expenses and income in one place, just like a bank statement.',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool bold;
  const _SummaryChip({required this.label, required this.amount, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final gu = context.read<SettingsProvider>().isGujarati;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          gu ? GujaratiNumberHelper.formatCurrency(amount, gujarati: true) : '₹${amount.toInt()}',
          style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: 16)
        ),
      ]),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final StatementEntry entry;
  final bool isGujarati;
  final bool showCrop;
  final bool showField;
  
  const _EntryRow({
    required this.entry,
    required this.isGujarati,
    this.showCrop = false,
    this.showField = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIncome = entry.type == 'Harvest' || entry.type == 'ઉત્પાદન';
    final amountColor = isIncome ? Colors.green : cs.error;
    final d = DateTime.fromMillisecondsSinceEpoch(entry.date);
    final dateStr = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}';
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 36, child: Text(dateStr, style: TextStyle(color: cs.outline, fontSize: 11))),
          const SizedBox(width: 8),
          Container(
            width: 45,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: amountColor.withAlpha(20), borderRadius: BorderRadius.circular(4)),
            child: Text(entry.type, style: TextStyle(color: amountColor, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          ),
          if (showCrop) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 50,
              child: Text(
                LanguageMapper.localizedCrop(entry.crop ?? '', isGujarati, context.read<GlobalOptionsProvider>().getGlobalCropMap(isGujarati)),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (showField) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 50,
              child: Text(
                entry.field ?? '-',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(child: Text(entry.description, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          Text(
            '${isIncome ? '+' : '-'}₹${entry.amount.toInt()}',
            style: TextStyle(fontWeight: FontWeight.w600, color: amountColor, fontSize: 13),
          ),
        ]),
      ),
    );
  }
}

class PdfViewerPage extends StatefulWidget {
  final Future<Uint8List?> Function(PdfPageFormat format) onBuild;
  final String title;

  const PdfViewerPage({super.key, required this.onBuild, required this.title});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  px.PdfControllerPinch? _pdfController;
  PdfPageFormat _format = PdfPageFormat.a4;
  bool _loading = true;
  Uint8List? _currentBytes;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    setState(() => _loading = true);
    final bytes = await widget.onBuild(_format);
    if (bytes != null) {
      _currentBytes = bytes;
      _pdfController = px.PdfControllerPinch(
        document: px.PdfDocument.openData(bytes),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleOrientation() async {
    final newFormat = _format.width > _format.height 
      ? PdfPageFormat.a4 
      : PdfPageFormat.a4.landscape;
    setState(() {
      _format = newFormat;
      _loading = true;
    });
    final bytes = await widget.onBuild(newFormat);
    if (bytes != null) {
      _currentBytes = bytes;
      _pdfController?.dispose();
      _pdfController = px.PdfControllerPinch(
        document: px.PdfDocument.openData(bytes),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.screen_rotation_rounded),
            onPressed: _loading ? null : _toggleOrientation,
            tooltip: 'Rotate Landscape',
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _currentBytes == null ? null : () => Printing.sharePdf(
              bytes: _currentBytes!,
              filename: 'Statement.pdf',
            ),
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            onPressed: _currentBytes == null ? null : () => Printing.layoutPdf(
              onLayout: (format) => _currentBytes!,
              name: 'Statement',
            ),
            tooltip: 'Print',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pdfController == null
              ? const Center(child: Text('Error loading PDF'))
              : px.PdfViewPinch(
                  controller: _pdfController!,
                ),
    );
  }
}
