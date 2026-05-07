import 'package:meta/meta.dart';

@immutable
class CachedEntityRecord {
  final String entityType;
  final String id;
  final Map<String, Object?> json;
  final DateTime updatedAt;
  final DateTime lastAccessedAt;
  final int cacheVersion;
  final bool pendingSync;

  const CachedEntityRecord({
    required this.entityType,
    required this.id,
    required this.json,
    required this.updatedAt,
    DateTime? lastAccessedAt,
    required this.cacheVersion,
    this.pendingSync = false,
  }) : lastAccessedAt = lastAccessedAt ?? updatedAt;

  String get storageKey => storageKeyFor(entityType, id);

  CachedEntityRecord markAccessed(DateTime at) {
    return CachedEntityRecord(
      entityType: entityType,
      id: id,
      json: json,
      updatedAt: updatedAt,
      lastAccessedAt: at,
      cacheVersion: cacheVersion,
      pendingSync: pendingSync,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'entityType': entityType,
      'id': id,
      'json': json,
      'updatedAt': updatedAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
      'cacheVersion': cacheVersion,
      'pendingSync': pendingSync,
    };
  }

  factory CachedEntityRecord.fromJson(Map<String, Object?> json) {
    return CachedEntityRecord(
      entityType: json['entityType']! as String,
      id: json['id']! as String,
      json: Map<String, Object?>.from(json['json']! as Map),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      lastAccessedAt: DateTime.parse(json['lastAccessedAt']! as String),
      cacheVersion: json['cacheVersion']! as int,
      pendingSync: json['pendingSync'] as bool? ?? false,
    );
  }

  static String storageKeyFor(String entityType, Object id) {
    return 'entity/$entityType/$id';
  }
}
