import 'package:riverpod_for_serverpod_runtime/src/cache/cached_entity_record.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/cached_index_record.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/generated_cache_storage.dart';

typedef EntityIdReader<T> = Object? Function(T entity);
typedef EntityJsonWriter<T> = Map<String, Object?> Function(T entity);
typedef EntityJsonReader<T> = T Function(Map<String, Object?> json);

class GeneratedEntityCache<T> {
  final GeneratedCacheStorage storage;
  final String entityType;
  final int cacheVersion;
  final EntityIdReader<T> idOf;
  final EntityJsonWriter<T> toJson;
  final EntityJsonReader<T> fromJson;
  final int? maxItems;
  final DateTime Function() now;

  const GeneratedEntityCache({
    required this.storage,
    required this.entityType,
    required this.cacheVersion,
    required this.idOf,
    required this.toJson,
    required this.fromJson,
    this.maxItems,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  Future<void> putOne(T entity, {bool pendingSync = false}) async {
    final id = idOf(entity);
    if (id == null) {
      throw ArgumentError.value(entity, 'entity', 'Entity id cannot be null.');
    }

    await storage.writeEntity(
      CachedEntityRecord(
        entityType: entityType,
        id: '$id',
        json: toJson(entity),
        updatedAt: now(),
        cacheVersion: cacheVersion,
        pendingSync: pendingSync,
      ),
    );
    await evictLeastRecentlyUsed();
  }

  Future<T?> getById(Object id) async {
    final record = await storage.readEntity(entityType, '$id');
    if (record == null || record.cacheVersion != cacheVersion) return null;

    final accessed = record.markAccessed(now());
    await storage.writeEntity(accessed);
    return fromJson(accessed.json);
  }

  Future<void> putList(
    String indexKey,
    List<T> entities, {
    required Duration ttl,
  }) async {
    final ids = <String>[];
    for (final entity in entities) {
      final id = idOf(entity);
      if (id == null) {
        throw ArgumentError.value(
          entity,
          'entities',
          'Entity id cannot be null.',
        );
      }
      ids.add('$id');
      await putOne(entity);
    }

    await storage.writeIndex(
      CachedIndexRecord(
        entityType: entityType,
        indexKey: indexKey,
        ids: ids,
        updatedAt: now(),
        ttl: ttl,
        cacheVersion: cacheVersion,
      ),
    );
  }

  Future<List<T>?> readList(
    String indexKey, {
    bool allowStale = false,
  }) async {
    final index = await storage.readIndex(entityType, indexKey);
    if (index == null ||
        index.cacheVersion != cacheVersion ||
        (!allowStale && !index.isFresh(now()))) {
      return null;
    }

    final entities = <T>[];
    for (final id in index.ids) {
      final entity = await getById(id);
      if (entity == null) return null;
      entities.add(entity);
    }
    return entities;
  }

  Future<List<T>?> readStaleList(String indexKey) {
    return readList(indexKey, allowStale: true);
  }

  Future<void> evictLeastRecentlyUsed() async {
    final limit = maxItems;
    if (limit == null) return;
    if (limit < 1) {
      throw ArgumentError.value(
          limit, 'maxItems', 'maxItems must be at least 1.');
    }

    final records = await storage.readEntitiesByType(entityType);
    final currentVersionRecords = [
      for (final record in records)
        if (record.cacheVersion == cacheVersion) record,
    ];
    if (currentVersionRecords.length <= limit) return;

    final evictable = [
      for (final record in currentVersionRecords)
        if (!record.pendingSync) record,
    ]..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));

    var overflow = currentVersionRecords.length - limit;
    for (final record in evictable) {
      if (overflow <= 0) break;
      await storage.deleteEntity(entityType, record.id);
      overflow--;
    }
  }
}
