import 'package:uuid/uuid.dart';

class InvestmentItem {
  final int? id;
  final String uuid;
  final String investmentUuid;
  final String itemName;
  final double quantity;
  final double pricePerUnit;
  final int updatedAt;

  InvestmentItem({
    this.id,
    String? uuid,
    required this.investmentUuid,
    required this.itemName,
    required this.quantity,
    required this.pricePerUnit,
    int? updatedAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  double get totalAmount => quantity * pricePerUnit;

  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'investmentUuid': investmentUuid,
        'itemName': itemName,
        'quantity': quantity,
        'pricePerUnit': pricePerUnit,
        'updatedAt': updatedAt,
      };

  factory InvestmentItem.fromMap(Map<String, dynamic> m) => InvestmentItem(
        id: m['id'] as int?,
        uuid: m['uuid'] as String? ?? const Uuid().v4(),
        investmentUuid: m['investmentUuid'] as String? ?? '',
        itemName: m['itemName'] as String? ?? '',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
        pricePerUnit: (m['pricePerUnit'] as num?)?.toDouble() ?? 0,
        updatedAt: m['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      );

  InvestmentItem copyWith({
    int? id,
    String? uuid,
    String? investmentUuid,
    String? itemName,
    double? quantity,
    double? pricePerUnit,
    int? updatedAt,
  }) =>
      InvestmentItem(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        investmentUuid: investmentUuid ?? this.investmentUuid,
        itemName: itemName ?? this.itemName,
        quantity: quantity ?? this.quantity,
        pricePerUnit: pricePerUnit ?? this.pricePerUnit,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
