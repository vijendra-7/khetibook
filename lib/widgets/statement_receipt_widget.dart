import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/statement_entry.dart';
import '../utils/language_mapper.dart';
import '../utils/gujarati_number_helper.dart';

// Fixed inner width breakdown (outer: 595, padding: 28*2 = 56, inner: 539)
double get _kDate => 62.0;
double get _kType => 58.0;
double get _kCrop => 60.0;
double get _kField => 65.0;
double get _kIncome => 78.0;
double get _kExpense => 78.0;

class StatementReceiptWidget extends StatelessWidget {
  final bool gu;
  final String crop;
  final int year;
  final List<StatementEntry> entries;
  final double totalInvestment;
  final double totalHarvest;
  final double netProfit;
  final Uint8List logoBytes;
  final String? fieldName;
  final bool showCrop;
  final bool showField;
  final Map<String, String>? globalCropMap;

  const StatementReceiptWidget({
    super.key,
    required this.gu,
    required this.crop,
    required this.year,
    required this.entries,
    required this.totalInvestment,
    required this.totalHarvest,
    required this.netProfit,
    required this.logoBytes,
    this.fieldName,
    this.showCrop = false,
    this.showField = false,
    this.globalCropMap,
  });

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final res =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return gu ? GujaratiNumberHelper.toGujarati(res) : res;
  }

  @override
  Widget build(BuildContext context) {
    final cropLoc = LanguageMapper.localizedCrop(crop, gu, globalCropMap);

    return MediaQuery(
      data: const MediaQueryData(size: Size(595, 10000)), // Provide a huge height for large statements
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: 595, // A4 width in points
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.memory(logoBytes, width: 44, height: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gu ? 'ખેતીબુક' : 'KhetiBook',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        Text(
                          gu 
                            ? (fieldName == null ? 'ચોપડો - $cropLoc' : 'ચોપડો - $cropLoc ($fieldName)')
                            : (fieldName == null ? 'Statement - $cropLoc' : 'Statement - $cropLoc ($fieldName)'),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(gu ? 'વર્ષ' : 'Year',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      Text(
                        gu ? GujaratiNumberHelper.toGujaratiInt(year) : year.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(thickness: 1.2, color: Color(0xFFDDDDDD)),
              const SizedBox(height: 14),

              // ── Quick Summary Header ──────────────────────────────
              Row(
                children: [
                  _statItem(gu ? 'કુલ ખર્ચ' : 'Total Expense', totalInvestment, Colors.red.shade700),
                  const SizedBox(width: 12),
                  _statItem(gu ? 'કુલ આવક' : 'Total Income', totalHarvest, Colors.green.shade700),
                  const SizedBox(width: 12),
                  _statItem(gu ? 'ચોખ્ખો નફો' : 'Net Profit', netProfit, Colors.blue.shade800, isMain: true),
                ],
              ),

              const SizedBox(height: 20),

              // ── Table header ───────────────────────────────────────
              _buildHeader(gu),
              // ── Rows ───────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade300),
                    right: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < entries.length; i++) _buildRow(entries[i], i),
                  ],
                ),
              ),

              // Bottom line of the table
              Container(height: 1, color: Colors.grey.shade300),

              const SizedBox(height: 18),

              // ── Summary ────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _sumRow(
                      gu ? 'કુલ ખર્ચ:' : 'Total Expense:',
                      GujaratiNumberHelper.formatCurrency(totalInvestment,
                          gujarati: gu),
                      Colors.red.shade700,
                    ),
                    const SizedBox(height: 7),
                    _sumRow(
                      gu ? 'કુલ આવક:' : 'Total Income:',
                      GujaratiNumberHelper.formatCurrency(totalHarvest,
                          gujarati: gu),
                      Colors.green.shade700,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(thickness: 1, color: Colors.black26),
                    ),
                    _sumRow(
                      gu ? 'ચોખ્ખો નફો:' : 'Net Profit:',
                      GujaratiNumberHelper.formatCurrency(netProfit,
                          gujarati: gu),
                      Colors.black87,
                      bold: true,
                      large: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Center(
                child: Text(
                  gu
                      ? 'KhetiBook દ્વારા જનરેટ કરેલ'
                      : 'Generated by KhetiBook',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildHeader(bool gu) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF388E3C),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
        border: Border.all(color: const Color(0xFF2E7D32)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _vBorder(),
            Container(width: _kDate, padding: const EdgeInsets.all(8), child: _hdr(gu ? 'તારીખ' : 'Date')),
            _vBorder(),
            Container(width: _kType, padding: const EdgeInsets.all(8), child: _hdr(gu ? 'પ્રકાર' : 'Type')),
            if (showCrop) ...[
              _vBorder(),
              Container(width: _kCrop, padding: const EdgeInsets.all(8), child: _hdr(gu ? 'પાક' : 'Crop')),
            ],
            if (showField) ...[
              _vBorder(),
              Container(width: _kField, padding: const EdgeInsets.all(8), child: _hdr(gu ? 'ખેતર' : 'Field')),
            ],
            _vBorder(),
            Expanded(child: Padding(padding: const EdgeInsets.all(8), child: _hdr(gu ? 'વિગત' : 'Description'))),
            _vBorder(),
            Container(width: _kIncome, padding: const EdgeInsets.all(8), child: _hdr(gu ? 'આવક' : 'Income', right: true)),
            _vBorder(),
            Container(width: _kExpense, padding: const EdgeInsets.all(8), child: _hdr(gu ? 'ખર્ચ' : 'Expense', right: true)),
            _vBorder(),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String title, double amount, Color color, {bool isMain = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              GujaratiNumberHelper.formatCurrency(amount, gujarati: gu),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hdr(String text, {bool right = false}) => Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
      );

  Widget _vBorder({bool light = false}) => Container(
        width: 1,
        color: light ? Colors.grey.shade400 : const Color(0xFF2E7D32).withOpacity(0.7),
      );

  Widget _buildRow(StatementEntry entry, int index) {
    final isHarvest = entry.type == (gu ? 'ઉત્પાદન' : 'Harvest');
    final amtStr =
        GujaratiNumberHelper.formatCurrency(entry.amount, gujarati: gu);

    return Container(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : const Color(0xFFF9F9F9),
        border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _vBorder(light: true),
            Container(
              width: _kDate,
              padding: const EdgeInsets.all(8),
              child: Text(_fmtDate(entry.date),
                  style: const TextStyle(fontSize: 9, color: Colors.black87, fontWeight: FontWeight.w500)),
            ),
            _vBorder(light: true),
            Container(
              width: _kType,
              padding: const EdgeInsets.all(8),
              child: Text(
                entry.type,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isHarvest
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
            ),
            if (showCrop) ...[
              _vBorder(light: true),
              Container(
                width: _kCrop,
                padding: const EdgeInsets.all(8),
                child: Text(
                  LanguageMapper.localizedCrop(entry.crop ?? '', gu, globalCropMap),
                  style: const TextStyle(fontSize: 9, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (showField) ...[
              _vBorder(light: true),
              Container(
                width: _kField,
                padding: const EdgeInsets.all(8),
                child: Text(
                  entry.field ?? '-',
                  style: const TextStyle(fontSize: 9, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            _vBorder(light: true),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  entry.description,
                  style: const TextStyle(fontSize: 9, color: Colors.black87),
                  softWrap: true,
                ),
              ),
            ),
            _vBorder(light: true),
            Container(
              width: _kIncome,
              padding: const EdgeInsets.all(8),
              child: Text(
                isHarvest ? amtStr : '',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700),
              ),
            ),
            _vBorder(light: true),
            Container(
              width: _kExpense,
              padding: const EdgeInsets.all(8),
              child: Text(
                !isHarvest ? amtStr : '',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700),
              ),
            ),
            _vBorder(light: true),
          ],
        ),
      ),
    );
  }

  Widget _sumRow(String label, String value, Color color,
      {bool bold = false, bool large = false}) {
    final fs = large ? 15.0 : 12.0;
    final fw = bold ? FontWeight.bold : FontWeight.w600;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fs, fontWeight: fw, color: color)),
        Text(value, style: TextStyle(fontSize: fs, fontWeight: fw, color: color)),
      ],
    );
  }
}
