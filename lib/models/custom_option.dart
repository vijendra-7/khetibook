import 'package:uuid/uuid.dart';

class CustomOption {
  final int? id;
  final String uuid;
  final String category;
  final String value;
  final int updatedAt;
  final String syncStatus; // 'synced', 'pending'
  final bool isDeleted;

  CustomOption({
    this.id,
    String? uuid,
    required this.category,
    required this.value,
    int? updatedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
  })  : uuid = uuid ?? const Uuid().v4(),
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'category': category,
      'value': value,
      'updatedAt': updatedAt,
      'syncStatus': syncStatus,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory CustomOption.fromMap(Map<String, dynamic> map) {
    return CustomOption(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      category: map['category'] as String,
      value: map['value'] as String,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      syncStatus: map['syncStatus'] as String? ?? 'pending',
      isDeleted: map['isDeleted'] is bool ? map['isDeleted'] as bool : (map['isDeleted'] as num?)?.toInt() == 1,
    );
  }

  CustomOption copyWith({
    int? id,
    String? uuid,
    String? category,
    String? value,
    int? updatedAt,
    String? syncStatus,
    bool? isDeleted,
  }) {
    return CustomOption(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      category: category ?? this.category,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
