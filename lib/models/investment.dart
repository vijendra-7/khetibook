import 'package:uuid/uuid.dart';
import 'investment_item.dart';

class Investment {
  final int? id;
  final String uuid;
  final String crop;
  final String investmentType;
  final String investmentTypeOther;
  final String seedType;
  final double kataQuantity;
  final double pricePerKata;
  final String vigha;
  final double cost;
  final String serviceProvider;
  final bool isPaid;
  final double pendingAmount;
  final int date; // transaction timestamp ms
  final int updatedAt; // modification timestamp ms
  final String syncStatus; // 'pending' or 'synced'
  final bool isDeleted;
  final int? deletedAt;
  final String biyaranCompany;
  final String fieldName;
  final List<InvestmentItem> items;

  Investment({
    this.id,
    String? uuid,
    required this.crop,
    required this.investmentType,
    this.investmentTypeOther = '',
    this.seedType = '',
    this.biyaranCompany = '',
    this.fieldName = '',
    this.kataQuantity = 0,
    this.pricePerKata = 0,
    this.vigha = '',
    this.cost = 0,
    this.serviceProvider = '',
    this.isPaid = true,
    this.pendingAmount = 0,
    required this.date,
    int? updatedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
    this.deletedAt,
    this.items = const [],
  })  : uuid = uuid ?? const Uuid().v4(),
        updatedAt = updatedAt ?? date;

  double get totalAmount {
    if (investmentType == 'Biyaran') {
      return kataQuantity * pricePerKata;
    }
    if (investmentType == 'Dawa' || investmentType == 'Khatar') {
      if (items.isNotEmpty) {
        return items.fold(0, (sum, item) => sum + item.totalAmount);
      }
      // Fallback for legacy data/direct cost
      return cost;
    }
    return cost;
  }

  String get displayInvestmentType =>
      ((investmentType == 'Others' || investmentType == 'Dawa' || investmentType == 'Khatar') &&
              investmentTypeOther.isNotEmpty)
          ? investmentTypeOther
          : investmentType;

  /// Full map for Firestore sync (includes items)
  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'crop': crop,
        'investmentType': investmentType,
        'investmentTypeOther': investmentTypeOther,
        'seedType': seedType,
        'biyaranCompany': biyaranCompany,
        'fieldName': fieldName,
        'kataQuantity': kataQuantity,
        'pricePerKata': pricePerKata,
        'vigha': vigha,
        'cost': cost,
        'serviceProvider': serviceProvider,
        'isPaid': isPaid ? 1 : 0,
        'pendingAmount': pendingAmount,
        'date': date,
        'updatedAt': updatedAt,
        'syncStatus': syncStatus,
        'isDeleted': isDeleted ? 1 : 0,
        'deletedAt': deletedAt,
        'items': items.map((i) => i.toMap()).toList(),
      };

  /// Flattened map for SQLite (excludes items)
  Map<String, dynamic> toSqlMap() => {
        'id': id,
        'uuid': uuid,
        'crop': crop,
        'investmentType': investmentType,
        'investmentTypeOther': investmentTypeOther,
        'seedType': seedType,
        'biyaranCompany': biyaranCompany,
        'fieldName': fieldName,
        'kataQuantity': kataQuantity,
        'pricePerKata': pricePerKata,
        'vigha': vigha,
        'cost': cost,
        'serviceProvider': serviceProvider,
        'isPaid': isPaid ? 1 : 0,
        'pendingAmount': pendingAmount,
        'date': date,
        'updatedAt': updatedAt,
        'syncStatus': syncStatus,
        'isDeleted': isDeleted ? 1 : 0,
        'deletedAt': deletedAt,
      };

  factory Investment.fromMap(Map<String, dynamic> m) => Investment(
        id: m['id'] as int?,
        uuid: m['uuid'] as String? ?? const Uuid().v4(),
        crop: m['crop'] as String? ?? 'Unknown',
        investmentType: m['investmentType'] as String? ?? '',
        investmentTypeOther: m['investmentTypeOther'] as String? ?? '',
        seedType: m['seedType'] as String? ?? '',
        biyaranCompany: m['biyaranCompany'] as String? ?? '',
        fieldName: m['fieldName'] as String? ?? '',
        kataQuantity: (m['kataQuantity'] as num?)?.toDouble() ?? 0,
        pricePerKata: (m['pricePerKata'] as num?)?.toDouble() ?? 0,
        vigha: m['vigha'] as String? ?? '',
        cost: (m['cost'] as num?)?.toDouble() ?? 0,
        serviceProvider: m['serviceProvider'] as String? ?? '',
        isPaid: (m['isPaid'] as int?) == 1,
        pendingAmount: (m['pendingAmount'] as num?)?.toDouble() ?? 0,
        date: (m['date'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? (m['date'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        syncStatus: m['syncStatus'] as String? ?? 'pending',
        isDeleted: m['isDeleted'] is bool ? m['isDeleted'] as bool : (m['isDeleted'] as num?)?.toInt() == 1,
        deletedAt: (m['deletedAt'] as num?)?.toInt(),
        items: m['items'] != null
            ? (m['items'] as List).map((i) => InvestmentItem.fromMap(Map<String, dynamic>.from(i))).toList()
            : [],
      );

  Investment copyWith({
    int? id,
    String? uuid,
    String? crop,
    String? investmentType,
    String? investmentTypeOther,
    String? seedType,
    String? biyaranCompany,
    String? fieldName,
    double? kataQuantity,
    double? pricePerKata,
    String? vigha,
    double? cost,
    String? serviceProvider,
    bool? isPaid,
    double? pendingAmount,
    int? date,
    int? updatedAt,
    String? syncStatus,
    bool? isDeleted,
    int? deletedAt,
    List<InvestmentItem>? items,
  }) {
    return Investment(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      crop: crop ?? this.crop,
      investmentType: investmentType ?? this.investmentType,
      investmentTypeOther: investmentTypeOther ?? this.investmentTypeOther,
      seedType: seedType ?? this.seedType,
      biyaranCompany: biyaranCompany ?? this.biyaranCompany,
      fieldName: fieldName ?? this.fieldName,
      kataQuantity: kataQuantity ?? this.kataQuantity,
      pricePerKata: pricePerKata ?? this.pricePerKata,
      vigha: vigha ?? this.vigha,
      cost: cost ?? this.cost,
      serviceProvider: serviceProvider ?? this.serviceProvider,
      isPaid: isPaid ?? this.isPaid,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      date: date ?? this.date,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      items: items ?? this.items,
    );
  }
}
