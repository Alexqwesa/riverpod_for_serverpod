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

  static String storageKeyFor(String entityType, Object id) {
    return 'entity/$entityType/$id';
  }
}
