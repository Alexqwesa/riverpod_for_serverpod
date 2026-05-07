import 'package:meta/meta.dart';

@immutable
class CachedIndexRecord {
  final String entityType;
  final String indexKey;
  final List<String> ids;
  final DateTime updatedAt;
  final Duration ttl;
  final int cacheVersion;

  const CachedIndexRecord({
    required this.entityType,
    required this.indexKey,
    required this.ids,
    required this.updatedAt,
    required this.ttl,
    required this.cacheVersion,
  });

  String get storageKey => storageKeyFor(entityType, indexKey);

  bool isFresh(DateTime now) {
    return !updatedAt.add(ttl).isBefore(now);
  }

  static String storageKeyFor(String entityType, String indexKey) {
    return 'index/$entityType/$indexKey';
  }
}
