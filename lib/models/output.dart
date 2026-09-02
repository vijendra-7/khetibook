import 'package:uuid/uuid.dart';

class Output {
  final int? id;
  final String uuid;
  final String crop;
  final String field;
  final int bharati;
  final double remainingKg;
  final double pricePer20kg;
  final String vigha;
  final String soldTo;
  final int date; // transaction timestamp ms
  final int updatedAt; // modification timestamp ms
  final String syncStatus; // 'pending' or 'synced'
  final bool isDeleted;
  final int? deletedAt;

  Output({
    this.id,
    String? uuid,
    required this.crop,
    required this.field,
    this.vigha = '',
    required this.bharati,
    this.remainingKg = 0,
    required this.pricePer20kg,
    this.soldTo = '',
    required this.date,
    int? updatedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
    this.deletedAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        updatedAt = updatedAt ?? date;

  double get revenue {
    if (crop == 'Tarbuch') {
      return remainingKg * pricePer20kg;
    }
    
    // Standard crops that use weights/20kg logic
    final isStandard = ['Bataka', 'Magfali', 'Bajari', 'Ghau', 'Cauliflower', 'Gavar'].contains(crop);
    
    if (!isStandard) {
      // Custom crop: simple quantity * price
      return bharati * pricePer20kg;
    }

    final weightMultiplier = (crop == 'Bajari' || crop == 'Ghau')
        ? 99.0
        : (crop == 'Bataka' ? 80.0 : 34.0);
    final totalKg = (bharati * weightMultiplier) + remainingKg;
    final units20kg = totalKg / 20.0;
    return units20kg * pricePer20kg;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'crop': crop,
        'field': field,
        'vigha': vigha,
        'bharati': bharati,
        'remainingKg': remainingKg,
        'pricePer20kg': pricePer20kg,
        'soldTo': soldTo,
        'date': date,
        'updatedAt': updatedAt,
        'syncStatus': syncStatus,
        'isDeleted': isDeleted ? 1 : 0,
        'deletedAt': deletedAt,
      };

  factory Output.fromMap(Map<String, dynamic> m) => Output(
        id: m['id'] as int?,
        uuid: m['uuid'] as String? ?? const Uuid().v4(),
        crop: m['crop'] as String,
        field: m['field'] as String,
        vigha: m['vigha'] as String? ?? '',
        bharati: m['bharati'] as int,
        remainingKg: (m['remainingKg'] as num?)?.toDouble() ?? 0,
        pricePer20kg: (m['pricePer20kg'] as num?)?.toDouble() ?? 0,
        soldTo: m['soldTo'] as String? ?? '',
        date: (m['date'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? (m['date'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        syncStatus: m['syncStatus'] as String? ?? 'pending',
        isDeleted: m['isDeleted'] is bool ? m['isDeleted'] as bool : (m['isDeleted'] as num?)?.toInt() == 1,
        deletedAt: (m['deletedAt'] as num?)?.toInt(),
      );

  Output copyWith({
    int? id,
    String? uuid,
    String? crop,
    String? field,
    String? vigha,
    int? bharati,
    double? remainingKg,
    double? pricePer20kg,
    String? soldTo,
    int? date,
    int? updatedAt,
    String? syncStatus,
    bool? isDeleted,
    int? deletedAt,
  }) =>
      Output(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        crop: crop ?? this.crop,
        field: field ?? this.field,
        vigha: vigha ?? this.vigha,
        bharati: bharati ?? this.bharati,
        remainingKg: remainingKg ?? this.remainingKg,
        pricePer20kg: pricePer20kg ?? this.pricePer20kg,
        soldTo: soldTo ?? this.soldTo,
        date: date ?? this.date,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}
