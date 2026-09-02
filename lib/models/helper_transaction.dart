import 'package:uuid/uuid.dart';

class HelperTransaction {
  final int? id;
  final String uuid;
  final String transactionType; // Upaad, Bhaag, Majur, Tractor
  final String helperName;
  final double amount;
  final int workerCount;
  final double amountPerWorker;
  final String field;
  final String vigha;
  final String equipmentType;
  final String crop; // Added for crop attribution
  final double hours;
  final double pricePerHour;
  final int date; // transaction timestamp ms
  final int updatedAt; // modification timestamp ms
  final String syncStatus; // 'pending' or 'synced'
  final bool isDeleted;
  final int? deletedAt;

  HelperTransaction({
    this.id,
    String? uuid,
    required this.transactionType,
    required this.helperName,
    this.amount = 0,
    this.workerCount = 0,
    this.amountPerWorker = 0,
    this.field = '',
    this.vigha = '',
    this.equipmentType = '',
    this.crop = '',
    this.hours = 0,
    this.pricePerHour = 0,
    required this.date,
    int? updatedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
    this.deletedAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        updatedAt = updatedAt ?? date;

  double get totalAmount {
    switch (transactionType) {
      case 'Majur':
        return workerCount * amountPerWorker;
      case 'Tractor':
        return equipmentType == 'Tola no Fero'
            ? amount
            : hours * pricePerHour;
      default:
        return amount;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'transactionType': transactionType,
        'helperName': helperName,
        'amount': amount,
        'workerCount': workerCount,
        'amountPerWorker': amountPerWorker,
        'field': field,
        'vigha': vigha,
        'equipmentType': equipmentType,
        'crop': crop,
        'hours': hours,
        'pricePerHour': pricePerHour,
        'date': date,
        'updatedAt': updatedAt,
        'syncStatus': syncStatus,
        'isDeleted': isDeleted ? 1 : 0,
        'deletedAt': deletedAt,
      };

  factory HelperTransaction.fromMap(Map<String, dynamic> m) =>
      HelperTransaction(
        id: m['id'] as int?,
        uuid: m['uuid'] as String? ?? const Uuid().v4(),
        transactionType: m['transactionType'] as String,
        helperName: m['helperName'] as String,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        workerCount: m['workerCount'] as int? ?? 0,
        amountPerWorker: (m['amountPerWorker'] as num?)?.toDouble() ?? 0,
        field: m['field'] as String? ?? '',
        vigha: m['vigha'] as String? ?? '',
        equipmentType: m['equipmentType'] as String? ?? '',
        crop: m['crop'] as String? ?? '',
        hours: (m['hours'] as num?)?.toDouble() ?? 0,
        pricePerHour: (m['pricePerHour'] as num?)?.toDouble() ?? 0,
        date: (m['date'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? (m['date'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        syncStatus: m['syncStatus'] as String? ?? 'pending',
        isDeleted: m['isDeleted'] is bool ? m['isDeleted'] as bool : (m['isDeleted'] as num?)?.toInt() == 1,
        deletedAt: (m['deletedAt'] as num?)?.toInt(),
      );

  HelperTransaction copyWith({
    int? id,
    String? uuid,
    String? transactionType,
    String? helperName,
    double? amount,
    int? workerCount,
    double? amountPerWorker,
    String? field,
    String? vigha,
    String? equipmentType,
    String? crop,
    double? hours,
    double? pricePerHour,
    int? date,
    int? updatedAt,
    String? syncStatus,
    bool? isDeleted,
    int? deletedAt,
  }) =>
      HelperTransaction(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        transactionType: transactionType ?? this.transactionType,
        helperName: helperName ?? this.helperName,
        amount: amount ?? this.amount,
        workerCount: workerCount ?? this.workerCount,
        amountPerWorker: amountPerWorker ?? this.amountPerWorker,
        field: field ?? this.field,
        vigha: vigha ?? this.vigha,
        equipmentType: equipmentType ?? this.equipmentType,
        crop: crop ?? this.crop,
        hours: hours ?? this.hours,
        pricePerHour: pricePerHour ?? this.pricePerHour,
        date: date ?? this.date,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}
