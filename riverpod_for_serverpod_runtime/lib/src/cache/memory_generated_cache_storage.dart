import 'package:riverpod_for_serverpod_runtime/src/cache/cached_entity_record.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/cached_index_record.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/generated_cache_storage.dart';

class MemoryGeneratedCacheStorage implements GeneratedCacheStorage {
  final _entities = <String, CachedEntityRecord>{};
  final _indexes = <String, CachedIndexRecord>{};

  @override
  Future<CachedEntityRecord?> readEntity(String entityType, String id) async {
    return _entities[CachedEntityRecord.storageKeyFor(entityType, id)];
  }

  @override
  Future<void> writeEntity(CachedEntityRecord record) async {
    _entities[record.storageKey] = record;
  }

  @override
  Future<void> deleteEntity(String entityType, String id) async {
    _entities.remove(CachedEntityRecord.storageKeyFor(entityType, id));
  }

  @override
  Future<List<CachedEntityRecord>> readEntitiesByType(String entityType) async {
    return [
      for (final record in _entities.values)
        if (record.entityType == entityType) record,
    ];
  }

  @override
  Future<CachedIndexRecord?> readIndex(
    String entityType,
    String indexKey,
  ) async {
    return _indexes[CachedIndexRecord.storageKeyFor(entityType, indexKey)];
  }

  @override
  Future<void> writeIndex(CachedIndexRecord record) async {
    _indexes[record.storageKey] = record;
  }

  @override
  Future<void> deleteIndex(String entityType, String indexKey) async {
    _indexes.remove(CachedIndexRecord.storageKeyFor(entityType, indexKey));
  }

  @override
  Future<void> clearEntityType(String entityType) async {
    _entities.removeWhere((_, record) => record.entityType == entityType);
    _indexes.removeWhere((_, record) => record.entityType == entityType);
  }
}
