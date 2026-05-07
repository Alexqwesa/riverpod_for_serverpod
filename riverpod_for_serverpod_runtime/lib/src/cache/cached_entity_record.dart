import 'package:meta/meta.dart';

@immutable
class CachedEntityRecord {
  final String entityType;
  final String id;
  final Map<String, Object?> json;
  final DateTime updatedAt;
  final int cacheVersion;
  final bool pendingSync;

  const CachedEntityRecord({
    required this.entityType,
    required this.id,
    required this.json,
    required this.updatedAt,
    required this.cacheVersion,
    this.pendingSync = false,
  });

  String get storageKey => storageKeyFor(entityType, id);

  static String storageKeyFor(String entityType, Object id) {
    return 'entity/$entityType/$id';
  }
}
