import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'package:intl/intl.dart';

class LandUnitConverterScreen extends StatefulWidget {
  const LandUnitConverterScreen({super.key});

  @override
  State<LandUnitConverterScreen> createState() => _LandUnitConverterScreenState();
}

class _LandUnitConverterScreenState extends State<LandUnitConverterScreen> {
  // Controllers
  final TextEditingController _vighaCtrl = TextEditingController();
  final TextEditingController _gunthaCtrl = TextEditingController();
  final TextEditingController _acreCtrl = TextEditingController();
  final TextEditingController _hectareCtrl = TextEditingController();
  final TextEditingController _sqmCtrl = TextEditingController();
  final TextEditingController _sqftCtrl = TextEditingController();
  
  FocusNode _vighaFocus = FocusNode();
  FocusNode _gunthaFocus = FocusNode();
  FocusNode _acreFocus = FocusNode();
  FocusNode _hectareFocus = FocusNode();
  FocusNode _sqmFocus = FocusNode();
  FocusNode _sqftFocus = FocusNode();

  bool _isUpdating = false;

  // Conversion rates relative to 1 Square Meter (sqm)
  // 1 Guntha = 101.17 sqm
  // 1 Vigha = 16 Guntha = 1618.72 sqm
  // 1 Acre = 40 Guntha = 4046.86 sqm
  // 1 Hectare = 10000 sqm
  // 1 Sq. Foot = 0.092903 sqm
  
  static const double _sqmPerGuntha = 101.17141056;
  static const double _sqmPerVigha = _sqmPerGuntha * 16.0;
  static const double _sqmPerAcre = _sqmPerGuntha * 40.0;
  static const double _sqmPerHectare = 10000.0;
  static const double _sqmPerSqft = 0.09290304;

  @override
  void initState() {
    super.initState();
    _vighaCtrl.addListener(() => _onTextChanged(_vighaCtrl, _sqmPerVigha));
    _gunthaCtrl.addListener(() => _onTextChanged(_gunthaCtrl, _sqmPerGuntha));
    _acreCtrl.addListener(() => _onTextChanged(_acreCtrl, _sqmPerAcre));
    _hectareCtrl.addListener(() => _onTextChanged(_hectareCtrl, _sqmPerHectare));
    _sqmCtrl.addListener(() => _onTextChanged(_sqmCtrl, 1.0));
    _sqftCtrl.addListener(() => _onTextChanged(_sqftCtrl, _sqmPerSqft));
  }
  
  @override
  void dispose() {
    _vighaCtrl.dispose();
    _gunthaCtrl.dispose();
    _acreCtrl.dispose();
    _hectareCtrl.dispose();
    _sqmCtrl.dispose();
    _sqftCtrl.dispose();
    _vighaFocus.dispose();
    _gunthaFocus.dispose();
    _acreFocus.dispose();
    _hectareFocus.dispose();
    _sqmFocus.dispose();
    _sqftFocus.dispose();
    super.dispose();
  }

  void _onTextChanged(TextEditingController sourceCtrl, double multiplier) {
    if (_isUpdating) return;
    
    // Only update if this is the active field being typed into
    bool isFocused = false;
    if (sourceCtrl == _vighaCtrl) isFocused = _vighaFocus.hasFocus;
    if (sourceCtrl == _gunthaCtrl) isFocused = _gunthaFocus.hasFocus;
    if (sourceCtrl == _acreCtrl) isFocused = _acreFocus.hasFocus;
    if (sourceCtrl == _hectareCtrl) isFocused = _hectareFocus.hasFocus;
    if (sourceCtrl == _sqmCtrl) isFocused = _sqmFocus.hasFocus;
    if (sourceCtrl == _sqftCtrl) isFocused = _sqftFocus.hasFocus;
    
    if (!isFocused) return;

    String text = sourceCtrl.text.replaceAll('૦', '0')
        .replaceAll('૧', '1')
        .replaceAll('૨', '2')
        .replaceAll('૩', '3')
        .replaceAll('૪', '4')
        .replaceAll('૫', '5')
        .replaceAll('૬', '6')
        .replaceAll('૭', '7')
        .replaceAll('૮', '8')
        .replaceAll('૯', '9');
        
    double? val = double.tryParse(text);
    
    if (val == null) {
      // Clear all others
      _updateAllExcept(sourceCtrl, '');
      return;
    }

    double sqmValue = val * multiplier;
    
    _isUpdating = true;
    _updateFieldIfNotSource(_vighaCtrl, sourceCtrl, (sqmValue / _sqmPerVigha));
    _updateFieldIfNotSource(_gunthaCtrl, sourceCtrl, (sqmValue / _sqmPerGuntha));
    _updateFieldIfNotSource(_acreCtrl, sourceCtrl, (sqmValue / _sqmPerAcre));
    _updateFieldIfNotSource(_hectareCtrl, sourceCtrl, (sqmValue / _sqmPerHectare));
    _updateFieldIfNotSource(_sqmCtrl, sourceCtrl, sqmValue);
    _updateFieldIfNotSource(_sqftCtrl, sourceCtrl, (sqmValue / _sqmPerSqft));
    _isUpdating = false;
  }
  
  void _updateAllExcept(TextEditingController sourceCtrl, String text) {
    _isUpdating = true;
    if (sourceCtrl != _vighaCtrl) _vighaCtrl.text = text;
    if (sourceCtrl != _gunthaCtrl) _gunthaCtrl.text = text;
    if (sourceCtrl != _acreCtrl) _acreCtrl.text = text;
    if (sourceCtrl != _hectareCtrl) _hectareCtrl.text = text;
    if (sourceCtrl != _sqmCtrl) _sqmCtrl.text = text;
    if (sourceCtrl != _sqftCtrl) _sqftCtrl.text = text;
    _isUpdating = false;
  }

  void _updateFieldIfNotSource(TextEditingController targetCtrl, TextEditingController sourceCtrl, double value) {
    if (targetCtrl != sourceCtrl) {
      // Format to 4 decimal places max, removing trailing zeros
      String formatted = value.toStringAsFixed(4);
      if (formatted.contains('.')) {
        formatted = formatted.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
      }
      
      final gu = context.read<SettingsProvider>().isGujarati;
      if (gu) {
        formatted = formatted
            .replaceAll('0', '૦')
            .replaceAll('1', '૧')
            .replaceAll('2', '૨')
            .replaceAll('3', '૩')
            .replaceAll('4', '૪')
            .replaceAll('5', '૫')
            .replaceAll('6', '૬')
            .replaceAll('7', '૭')
            .replaceAll('8', '૮')
            .replaceAll('9', '૯');
      }
      
      targetCtrl.text = formatted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: cs.surfaceContainerLowest,
        foregroundColor: cs.onSurface,
        title: Text(
          gu ? 'જમીન માપણી' : 'Land Converter',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFAED581)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF558B2F)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      gu 
                        ? 'કોઈ પણ બોક્સમાં જમીનનું માપ લખો, બાકીના માપ આપમેળે ગણાઈ જશે.\n(નોંધ: ૧ વીઘા = ૧૬ ગુંઠા)'
                        : 'Enter a value in any box and the others will calculate automatically.\n(Note: 1 Vigha = 16 Guntha)',
                      style: const TextStyle(color: Color(0xFF33691E), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            
            _buildInputRow(
              gu, 
              _vighaCtrl, _vighaFocus, gu ? 'વીઘા' : 'Vigha', 
              _gunthaCtrl, _gunthaFocus, gu ? 'ગુંઠા' : 'Guntha',
              cs,
            ),
            const SizedBox(height: 16),
            _buildInputRow(
              gu, 
              _acreCtrl, _acreFocus, gu ? 'એકર' : 'Acre', 
              _hectareCtrl, _hectareFocus, gu ? 'હેક્ટર' : 'Hectare',
              cs,
            ),
            const SizedBox(height: 16),
            _buildInputRow(
              gu, 
              _sqmCtrl, _sqmFocus, gu ? 'ચોરસ મીટર' : 'Sq. Meter', 
              _sqftCtrl, _sqftFocus, gu ? 'ચોરસ ફૂટ' : 'Sq. Feet',
              cs,
            ),
            
            const SizedBox(height: 40),
            Center(
              child: Image.asset(
                'assets/icons/new4.webp', 
                height: 120,
                opacity: const AlwaysStoppedAnimation(0.2),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(
    bool gu,
    TextEditingController ctrl1, FocusNode node1, String label1,
    TextEditingController ctrl2, FocusNode node2, String label2,
    ColorScheme cs,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(ctrl1, node1, label1, cs),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTextField(ctrl2, node2, label2, cs),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController ctrl, FocusNode node, String label, ColorScheme cs) {
    return TextField(
      controller: ctrl,
      focusNode: node,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9૧૨૩૪૫૬૭૮૯૦.]')),
      ],
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
    );
  }
}
