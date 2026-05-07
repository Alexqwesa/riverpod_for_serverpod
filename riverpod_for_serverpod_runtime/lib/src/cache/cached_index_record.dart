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

  Map<String, Object?> toJson() {
    return {
      'entityType': entityType,
      'indexKey': indexKey,
      'ids': ids,
      'updatedAt': updatedAt.toIso8601String(),
      'ttlMicroseconds': ttl.inMicroseconds,
      'cacheVersion': cacheVersion,
    };
  }

  factory CachedIndexRecord.fromJson(Map<String, Object?> json) {
    return CachedIndexRecord(
      entityType: json['entityType']! as String,
      indexKey: json['indexKey']! as String,
      ids: List<String>.from(json['ids']! as List),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      ttl: Duration(microseconds: json['ttlMicroseconds']! as int),
      cacheVersion: json['cacheVersion']! as int,
    );
  }

  static String storageKeyFor(String entityType, String indexKey) {
    return 'index/$entityType/$indexKey';
  }
}
