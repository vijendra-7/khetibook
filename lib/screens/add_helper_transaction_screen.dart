import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import '../database/app_database.dart';
import '../models/helper_transaction.dart';
import '../utils/language_mapper.dart';
import '../utils/validation_helper.dart';
import '../widgets/voice_input_button.dart';
import '../utils/custom_options_manager.dart';
import '../utils/gujarati_number_helper.dart';
import '../utils/summary_card_image_generator.dart';
import '../widgets/premium_select.dart';
import '../widgets/premium_autocomplete.dart';

class AddHelperTransactionScreen extends StatefulWidget {
  final String transactionType;
  final int typeIndex;
  final HelperTransaction? transaction;
  final bool isGujarati;
  final String? fixedPersonName;
 
   const AddHelperTransactionScreen({
     super.key,
     required this.transactionType,
     required this.typeIndex,
     this.transaction,
     required this.isGujarati,
     this.fixedPersonName,
   });

  @override
  State<AddHelperTransactionScreen> createState() => _AddHelperTransactionScreenState();
}

class _AddHelperTransactionScreenState extends State<AddHelperTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _boundaryKey = GlobalKey();
  late TextEditingController _nameCtrl, _amountCtrl, _workerCountCtrl, _amountPerWorkerCtrl;
  late TextEditingController _fieldCtrl, _vighaCtrl, _hoursCtrl, _minutesCtrl, _pricePerHourCtrl, _tractorAmountCtrl;
  late TextEditingController _driverCtrl, _equipmentCtrl, _equipmentOtherCtrl;
  late DateTime _date;
  bool _saving = false;
  bool _viewMode = false;
  bool _isSharingSummary = false;
  bool _isTolaFero = false;
  List<String> _drivers = [], _equipment = [];
  List<String> _helperOptions = [], _fieldOptions = [], _cropOptions = [];
  String _selectedCrop = 'Bataka';

  final ValueNotifier<double> _calcMajurNotifier = ValueNotifier(0);
  final ValueNotifier<double> _calcTractorNotifier = ValueNotifier(0);

  bool get _isUpaadBhaag => widget.typeIndex <= 1;
  bool get _isMajur => widget.typeIndex == 2;
  bool get _isTractor => widget.typeIndex == 3;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    final fixed = widget.fixedPersonName;
    _viewMode = t != null;
    _nameCtrl = TextEditingController(text: t?.transactionType != 'Tractor' ? (t?.helperName ?? fixed ?? '') : (fixed ?? ''));
    _driverCtrl = TextEditingController(text: t?.transactionType == 'Tractor' ? t!.helperName : (fixed ?? ''));
    _amountCtrl = TextEditingController(text: t != null ? t.amount.toString() : '');
    _workerCountCtrl = TextEditingController(text: t != null ? t.workerCount.toString() : '');
    _amountPerWorkerCtrl = TextEditingController(text: t != null ? t.amountPerWorker.toString() : '');
    _fieldCtrl = TextEditingController(text: t?.field ?? '');
    _vighaCtrl = TextEditingController(text: t?.vigha ?? '');
    
    final enEquip = t?.equipmentType ?? '';
    final predefined = ['Khed', 'Shed', 'Rotavator', 'Peyani', 'Plough', 'Zero', 'Thresher', 'Digger', 'Tola no Fero'];
    if (enEquip.isNotEmpty && !predefined.contains(enEquip)) {
      _equipmentCtrl = TextEditingController(text: LanguageMapper.localizedEquipmentType('Others', widget.isGujarati));
      _equipmentOtherCtrl = TextEditingController(text: enEquip);
    } else {
      _equipmentCtrl = TextEditingController(text: LanguageMapper.localizedEquipmentType(enEquip, widget.isGujarati));
      _equipmentOtherCtrl = TextEditingController();
    }
    
    _isTolaFero = enEquip == 'Tola no Fero';
    final wholeH = (t?.hours ?? 0).truncate();
    final mins = (((t?.hours ?? 0) - wholeH) * 60).round();
    _hoursCtrl = TextEditingController(text: wholeH != 0 ? wholeH.toString() : '');
    _minutesCtrl = TextEditingController(text: mins != 0 ? mins.toString() : '');
    _pricePerHourCtrl = TextEditingController(text: t != null && t.pricePerHour != 0 ? t.pricePerHour.toString() : '');
    _tractorAmountCtrl = TextEditingController(text: t != null && t.equipmentType == 'Tola no Fero' && t.amount != 0 ? t.amount.toString() : '');
    _selectedCrop = t?.crop ?? 'Bataka';
    _date = t != null ? DateTime.fromMillisecondsSinceEpoch(t.date) : DateTime.now();
    _loadOptions();

    _workerCountCtrl.addListener(_updateCalculations);
    _amountPerWorkerCtrl.addListener(_updateCalculations);
    _hoursCtrl.addListener(_updateCalculations);
    _minutesCtrl.addListener(_updateCalculations);
    _pricePerHourCtrl.addListener(_updateCalculations);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/logo.webp'), context);
  }

  Future<void> _loadOptions() async {
    final gu = widget.isGujarati;
    final customDrivers = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categoryDrivers);
    final customEquipment = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categoryEquipmentTypes);
    final customHelpers = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categoryHelpers);
    final customFields = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categoryFields);
    
    final dbDrivers = await AppDatabase.instance.getUniqueValues('helper_transactions', 'helperName');
    final dbEquipment = await AppDatabase.instance.getUniqueValues('helper_transactions', 'equipmentType');
    final dbHelpers = await AppDatabase.instance.getUniqueValues('helper_transactions', 'helperName');
    final dbFields = await AppDatabase.instance.getUniqueValues('helper_transactions', 'field');
    
    final d = {...customDrivers, ...dbDrivers}.map((e) => LanguageMapper.localizedDriver(e, gu)).toList();
    const group2Types = ['Khed', 'Shed', 'Rotavator', 'Peyani', 'Plough', 'Zero', 'Thresher', 'Digger', 'Tola no Fero', 'Others'];
    final uniqueEquip = <String>{...customEquipment, ...dbEquipment, ...group2Types};
    final e = uniqueEquip.map((item) => LanguageMapper.localizedEquipmentType(item, gu)).toList();
    
    final h = {...customHelpers, ...dbHelpers}.toList();
    final f = {...customFields, ...dbFields}.toList();
    final crops = await AppDatabase.instance.getUniqueValues('investments', 'crop');
    
    if (mounted) {
      setState(() { 
        _drivers = d; 
        _equipment = e; 
        _helperOptions = h;
        _fieldOptions = f;
        _cropOptions = crops.isEmpty ? ['Bataka', 'Bajari'] : crops;
        _cropOptions = _cropOptions.map((c) => LanguageMapper.localizedCrop(c, gu)).toList();
        if (!_cropOptions.contains(_selectedCrop) && _cropOptions.isNotEmpty) {
          _selectedCrop = _cropOptions.first;
        }
      });
    }
  }

  void _updateCalculations() {
    _calcMajurNotifier.value = (int.tryParse(_workerCountCtrl.text) ?? 0) * (double.tryParse(_amountPerWorkerCtrl.text) ?? 0);
    final h = (int.tryParse(_hoursCtrl.text) ?? 0) + ((int.tryParse(_minutesCtrl.text) ?? 0) / 60.0);
    _calcTractorNotifier.value = h * (double.tryParse(_pricePerHourCtrl.text) ?? 0);
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _amountCtrl, _workerCountCtrl, _amountPerWorkerCtrl, _fieldCtrl, _vighaCtrl, _hoursCtrl, _minutesCtrl, _pricePerHourCtrl, _tractorAmountCtrl, _driverCtrl, _equipmentCtrl, _equipmentOtherCtrl]) {
      c.dispose();
    }
    _calcMajurNotifier.dispose();
    _calcTractorNotifier.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    late HelperTransaction txn;
    if (_isUpaadBhaag) {
      txn = HelperTransaction(
        id: widget.transaction?.id,
        uuid: widget.transaction?.uuid,
        transactionType: widget.transactionType,
        helperName: _nameCtrl.text.trim(),
        field: widget.transactionType == 'Upaad' ? '' : _fieldCtrl.text.trim(),
        vigha: widget.transactionType == 'Upaad' ? '' : _vighaCtrl.text.trim(),
        amount: double.tryParse(_amountCtrl.text) ?? 0,
        crop: widget.transactionType == 'Bhaag' ? LanguageMapper.englishCrop(_selectedCrop, widget.isGujarati) : '',
        date: _date.millisecondsSinceEpoch,
      );
    } else if (_isMajur) {
      final cropEng = LanguageMapper.englishCrop(_selectedCrop, widget.isGujarati);
      txn = HelperTransaction(
        id: widget.transaction?.id,
        uuid: widget.transaction?.uuid,
        transactionType: widget.transactionType,
        helperName: _nameCtrl.text.trim(),
        field: _fieldCtrl.text.trim(),
        vigha: _vighaCtrl.text.trim(),
        workerCount: int.tryParse(_workerCountCtrl.text) ?? 0,
        amountPerWorker: double.tryParse(_amountPerWorkerCtrl.text) ?? 0,
        crop: cropEng,
        date: _date.millisecondsSinceEpoch,
      );
    } else {
      final driverEn = LanguageMapper.englishDriver(_driverCtrl.text.trim(), widget.isGujarati);
      final isOtherWork = LanguageMapper.englishEquipmentType(_equipmentCtrl.text.trim(), widget.isGujarati) == 'Others';
      String equipEn = isOtherWork ? _equipmentOtherCtrl.text.trim() : LanguageMapper.englishEquipmentType(_equipmentCtrl.text.trim(), widget.isGujarati);
      if (isOtherWork && equipEn.isEmpty) equipEn = 'Others';
      final h = (int.tryParse(_hoursCtrl.text) ?? 0) + ((int.tryParse(_minutesCtrl.text) ?? 0) / 60.0);
      txn = HelperTransaction(
        id: widget.transaction?.id,
        uuid: widget.transaction?.uuid,
        transactionType: widget.transactionType,
        helperName: driverEn,
        field: _fieldCtrl.text.trim(),
        vigha: _vighaCtrl.text.trim(),
        equipmentType: equipEn,
        amount: _isTolaFero ? (double.tryParse(_tractorAmountCtrl.text) ?? 0) : 0,
        hours: _isTolaFero ? 0 : h,
        pricePerHour: _isTolaFero ? 0 : (double.tryParse(_pricePerHourCtrl.text) ?? 0),
        date: _date.millisecondsSinceEpoch,
      );
    }
    if (widget.transaction == null) {
      await AppDatabase.instance.insertTransaction(txn);
    } else {
      await AppDatabase.instance.updateTransaction(txn);
    }

    if (!_isTractor && _nameCtrl.text.trim().isNotEmpty) {
      await CustomOptionsManager.addCustomOption(CustomOptionsManager.categoryHelpers, _nameCtrl.text.trim());
    }
    if (_isTractor) {
      if (_driverCtrl.text.trim().isNotEmpty) {
        await CustomOptionsManager.addCustomOption(CustomOptionsManager.categoryDrivers, _driverCtrl.text.trim());
      }
      final isOtherWork = LanguageMapper.englishEquipmentType(_equipmentCtrl.text.trim(), widget.isGujarati) == 'Others';
      final equipToSave = isOtherWork ? _equipmentOtherCtrl.text.trim() : _equipmentCtrl.text.trim();
      if (equipToSave.isNotEmpty && equipToSave != (widget.isGujarati ? 'અન્ય' : 'Others')) {
        await CustomOptionsManager.addCustomOption(CustomOptionsManager.categoryEquipmentTypes, equipToSave);
      }
    }
    if (_fieldCtrl.text.trim().isNotEmpty) await CustomOptionsManager.addCustomOption(CustomOptionsManager.categoryFields, _fieldCtrl.text.trim());
    
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final gu = widget.isGujarati;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(gu ? 'વ્યવહાર કાઢી નાખો?' : 'Delete'), 
        content: Text(gu ? 'ખીસાબમાં થી આ વ્યવહાર કાઢી નાખવો છે?' : 'Move to Recycle Bin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(gu ? 'રદ કરો' : 'Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(gu ? 'કાઢી નાખો' : 'Delete', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await AppDatabase.instance.softDeleteTransaction(widget.transaction!.id!);
      if (context.mounted) {
        Navigator.pop(context, 'deleted');
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(gu ? 'વ્યવહાર કાઢી નાખ્યો' : 'Transaction deleted'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: gu ? 'પાછું લાવો' : 'Undo',
              onPressed: () async {
                await AppDatabase.instance.restoreTransaction(widget.transaction!.id!);
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gu = widget.isGujarati;
    final cs = Theme.of(context).colorScheme;
    final title = widget.transaction == null 
        ? (gu ? 'નવો વ્યવહાર ઉમેરો' : 'Add New Transaction')
        : (_viewMode ? (gu ? 'વ્યવહાર વિગત' : 'Transaction Details') : (gu ? 'સંપાદિત' : 'Edit Transaction'));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.transaction != null && _viewMode) ...[
          ],
          if (widget.transaction != null && !_viewMode)
            IconButton(icon: const Icon(Icons.delete_outline), color: cs.error, onPressed: _delete),
        ],
      ),
      body: RepaintBoundary(
        key: _boundaryKey,
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _viewMode ? _buildSummary(gu) : Form(key: _formKey, child: _buildForm(gu, cs)),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandedHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/logo.webp', height: 40),
          const SizedBox(width: 12),
          const Text(
            'KhetiBook',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(bool gu) {
    final cs = Theme.of(context).colorScheme;
    final t = widget.transaction!;
    final d = DateTime.fromMillisecondsSinceEpoch(t.date);
    final res = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final dateStr = gu ? GujaratiNumberHelper.toGujarati(res) : res;
    final typeName = LanguageMapper.localizedTransactionType(t.transactionType, gu);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isSharingSummary) _buildBrandedHeader(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: const Color(0xFF1B5E20).withAlpha(60), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(20)),
                    child: Text(typeName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                gu ? GujaratiNumberHelper.formatCurrency(t.totalAmount, gujarati: true) : GujaratiNumberHelper.formatCurrency(t.totalAmount),
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1.0),
              ),
              const SizedBox(height: 6),
              Text(dateStr, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (t.transactionType != 'Upaad' && (t.field.isNotEmpty || t.vigha.isNotEmpty))
          _buildSummaryCard(
            gu ? 'ખેતરની માહિતી' : 'Farm Details',
            Icons.landscape_rounded,
            Colors.blue,
            '${t.field.isNotEmpty ? (gu ? GujaratiNumberHelper.toGujarati(t.field) : t.field) : (gu ? 'નામ નથી' : 'No Name')}${t.vigha.isNotEmpty ? " • ${gu ? GujaratiNumberHelper.toGujarati(t.vigha) : t.vigha} ${gu ? 'વિઘા' : 'Vigha'}" : ""}',
            cs,
            gu,
          ),
        if (t.helperName.isNotEmpty)
          _buildSummaryCard(
            _isTractor ? LanguageMapper.localizedPersonForWork(t.equipmentType, gu) : (gu ? 'ભાગીદારનું નામ' : 'Partner Name'),
            Icons.person_rounded,
            Colors.amber,
            t.helperName,
            cs,
            gu,
          ),
        if (t.crop.isNotEmpty)
          _summaryTile(icon: Icons.grass_rounded, label: gu ? 'ખેતી (પાક)' : 'Crop', value: LanguageMapper.localizedCrop(t.crop, gu), cs: cs),
        if (_isMajur) ...[
          _summaryTile(icon: Icons.groups_rounded, label: gu ? 'મજૂર' : 'Workers', value: GujaratiNumberHelper.formatNumber(t.workerCount.toDouble(), gujarati: gu), cs: cs),
          _summaryTile(icon: Icons.payments_rounded, label: gu ? 'ભાવ/મજૂર' : 'Rate/Worker', value: '₹${GujaratiNumberHelper.formatNumber(t.amountPerWorker, gujarati: gu)}', cs: cs),
        ],

        if (_isTractor) ...[
          _summaryTile(icon: Icons.agriculture_rounded, label: LanguageMapper.localizedWorkLabel(gu), value: LanguageMapper.localizedEquipmentType(t.equipmentType, gu), cs: cs),
          if (t.equipmentType != 'Tola no Fero') ...[
            _summaryTile(icon: Icons.schedule_rounded, label: gu ? 'સમય' : 'Hours', value: '${GujaratiNumberHelper.formatNumber(t.hours, gujarati: gu)}${gu ? ' કલાક' : 'h'}', cs: cs),
            _summaryTile(icon: Icons.payments_rounded, label: gu ? 'ભાવ/કલાક' : 'Rate/Hour', value: '₹${GujaratiNumberHelper.formatNumber(t.pricePerHour, gujarati: gu)}', cs: cs),
          ],
        ],

        const SizedBox(height: 24),
        if (!_isSharingSummary)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isSharingSummary = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await SummaryCardImageGenerator.shareScreenshot(_boundaryKey, isGujarati: gu);
                      if (mounted) setState(() => _isSharingSummary = false);
                    });
                  },
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
                  label: Text(gu ? 'વોટ્સએપ' : 'WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFF25D366)),
                    foregroundColor: const Color(0xFF25D366),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _viewMode = false);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(gu ? 'સંપાદિત કરો' : 'Edit'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, IconData icon, Color color, String value, ColorScheme cs, bool gu) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle), child: Icon(icon, color: color.withAlpha(220), size: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: color.withAlpha(220), fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile({required IconData icon, required String label, required String value, required ColorScheme cs}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)), child: Icon(icon, size: 22, color: cs.onSurfaceVariant)),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, color: cs.outline, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }

  Widget _buildForm(bool gu, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          title: gu ? 'પ્રાથમિક માહિતી' : 'Basic Information',
          icon: Icons.info_outline_rounded,
          cs: cs,
          children: [
            if (widget.transactionType == 'Majur' || widget.transactionType == 'Bhaag') ...[
              PremiumSelect(
                label: gu ? 'ખેતી (પાક) *' : 'Crop *',
                value: _selectedCrop,
                items: _cropOptions,
                hint: gu ? 'પાક પસંદ કરો' : 'Select crop',
                isGujarati: gu,
                icon: Icons.grass_rounded,
                onChanged: (s) => setState(() => _selectedCrop = s),
              ),
              const SizedBox(height: 16),
            ],
            if (!_isTractor) ...[
              PremiumAutocomplete(
                label: gu ? 'ભાગીદારનું નામ *' : 'Partner Name *',
                controller: _nameCtrl,
                options: _helperOptions,
                hint: gu ? 'ભાગીદારનું નામ' : 'Partner Name',
                isGujarati: gu,
                icon: Icons.person_outline_rounded,
                validator: (v) => v!.isEmpty ? (gu ? 'નામ પસંદ કરો' : 'Required') : null,
                suffix: VoiceInputButton(
                  controller: _nameCtrl,
                  onResult: () => setState(() {}),
                ),
              ),
            ] else ...[
              PremiumAutocomplete(
                label: '${LanguageMapper.localizedPersonForWork(_equipmentCtrl.text, gu)} *',
                controller: _driverCtrl,
                options: _drivers,
                hint: LanguageMapper.localizedPersonForWork(_equipmentCtrl.text, gu),
                isGujarati: gu,
                icon: Icons.person_outline_rounded,
                validator: (v) => v!.isEmpty ? (gu ? 'નામ પસંદ કરો' : 'Required') : null,
                suffix: VoiceInputButton(
                  controller: _driverCtrl,
                  onResult: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 16),
              PremiumSelect(
                label: '${LanguageMapper.localizedWorkLabel(gu)} *',
                value: _equipmentCtrl.text.isEmpty ? null : LanguageMapper.localizedEquipmentType(LanguageMapper.englishEquipmentType(_equipmentCtrl.text, gu), gu),
                items: _equipment,
                hint: gu ? 'કામ પસંદ કરો' : 'Select work',
                isGujarati: gu,
                icon: Icons.agriculture_rounded,
                onChanged: (s) {
                  setState(() {
                    _equipmentCtrl.text = s;
                    final en = LanguageMapper.englishEquipmentType(s, gu);
                    _isTolaFero = en == 'Tola no Fero';
                  });
                },
              ),
              if (LanguageMapper.englishEquipmentType(_equipmentCtrl.text, gu) == 'Others') ...[
                const SizedBox(height: 16),
                _lbl(gu ? 'અન્ય કામ નું નામ *' : 'Other Work Name *'),
                TextFormField(controller: _equipmentOtherCtrl, decoration: _inputDeco(gu ? 'કામ નું નામ' : 'Work name', cs, prefixIcon: Icons.edit_note_rounded)),
              ],
            ],
          ],
        ),
        _buildCard(
          title: gu ? 'વિગતો' : 'Details',
          icon: Icons.list_alt_rounded,
          cs: cs,
          children: [
            if (widget.transactionType != 'Upaad') ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      PremiumAutocomplete(
                        label: _isTractor ? (_isTolaFero ? (gu ? 'ક્યાં' : "Who's Fero") : (gu ? 'ખેતર ધરાવનાર નુ નામ' : 'Field Owner Name')) : (gu ? 'ખેતરનું નામ' : 'Field Name'),
                        controller: _fieldCtrl,
                        options: _fieldOptions,
                        hint: gu ? 'ખેતર' : 'Field',
                        isGujarati: gu,
                        icon: Icons.landscape_outlined,
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _lbl(gu ? 'વિઘા' : 'Vigha'),
                      TextFormField(controller: _vighaCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _inputDeco(gu ? 'વિઘા' : 'Vigha', cs, prefixIcon: Icons.straighten_rounded)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (_isTractor) ...[
              if (_isTolaFero) ...[
                _lbl(gu ? 'રકમ *' : 'Amount *'),
                TextFormField(controller: _tractorAmountCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('0', cs, prefixIcon: Icons.currency_rupee_rounded, prefixText: '₹ '), validator: (v) => ValidationHelper.validateAmount(v, gu)),
              ] else ...[
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_lbl(gu ? 'કલાક' : 'Hours'), TextFormField(controller: _hoursCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('0', cs, prefixIcon: Icons.timer_outlined))])),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_lbl(gu ? 'મિનિટ' : 'Minutes'), TextFormField(controller: _minutesCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('0', cs, prefixIcon: Icons.timelapse_rounded))])),
                ]),
                const SizedBox(height: 16),
                _lbl(gu ? 'ભાવ/કલાક' : 'Rate/Hour'),
                TextFormField(controller: _pricePerHourCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('0', cs, prefixIcon: Icons.currency_rupee_rounded, prefixText: '₹ ')),
              ],
            ] else if (_isUpaadBhaag) ...[
              _lbl(gu ? 'રકમ *' : 'Amount *'),
              TextFormField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('0', cs, prefixIcon: Icons.currency_rupee_rounded, prefixText: '₹ '), validator: (v) => ValidationHelper.validateAmount(v, gu)),
            ] else if (_isMajur) ...[
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_lbl(gu ? 'મજૂર *' : 'Workers *'), TextFormField(controller: _workerCountCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('0', cs, prefixIcon: Icons.groups_outlined), validator: (v) => ValidationHelper.validateAmount(v, gu))])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_lbl(gu ? 'ભાવ/મજૂર *' : 'Rate/Worker *'), TextFormField(controller: _amountPerWorkerCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('0', cs, prefixIcon: Icons.currency_rupee_rounded, prefixText: '₹ '), validator: (v) => ValidationHelper.validateAmount(v, gu))])),
              ]),
            ],
            const SizedBox(height: 16),
            _lbl(gu ? 'તારીખ' : 'Date'),
            InkWell(
              onTap: () async {
                final p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2035));
                if (p != null) setState(() => _date = p);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest.withAlpha(50), border: Border.all(color: cs.outlineVariant.withAlpha(80)), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 12),
                  Text(gu ? GujaratiNumberHelper.toGujarati('${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}') : '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFF1B5E20).withAlpha(60), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ElevatedButton(
            onPressed: _saving ? null : () { HapticFeedback.lightImpact(); _save(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _saving ? const CircularProgressIndicator(color: Colors.white) : Text(gu ? 'સાચવો' : 'Save Details', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children, required ColorScheme cs}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: cs.outlineVariant.withAlpha(80)), boxShadow: [BoxShadow(color: cs.shadow.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: cs.surfaceContainerHighest.withAlpha(40), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: [Icon(icon, size: 18, color: cs.primary), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary))])),
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
      ]),
    );
  }

  Widget _lbl(String text) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)));

  InputDecoration _inputDeco(String hint, ColorScheme cs, {IconData? prefixIcon, String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      prefixText: prefixText,
      prefixStyle: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withAlpha(100))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 2)),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withAlpha(30),
    );
  }
}
