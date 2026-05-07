import 'package:riverpod_for_serverpod_runtime/src/cache/cached_entity_record.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/cached_index_record.dart';

abstract interface class GeneratedCacheStorage {
  Future<CachedEntityRecord?> readEntity(String entityType, String id);

  Future<void> writeEntity(CachedEntityRecord record);

  Future<void> deleteEntity(String entityType, String id);

  Future<List<CachedEntityRecord>> readEntitiesByType(String entityType);

  Future<CachedIndexRecord?> readIndex(String entityType, String indexKey);

  Future<void> writeIndex(CachedIndexRecord record);

  Future<void> deleteIndex(String entityType, String indexKey);

  Future<void> clearEntityType(String entityType);
}
