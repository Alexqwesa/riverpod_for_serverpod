import 'package:riverpod_for_serverpod_runtime/src/cache/cached_entity_record.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/cached_index_record.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/generated_cache_storage.dart';

/// Adds a namespace to all cache keys while keeping public records unscoped.
///
/// This is useful for user-scoped or secure caches:
///
/// ```dart
/// NamespacedGeneratedCacheStorage(
///   inner: hiveStorage,
///   namespace: 'user/$userId',
/// )
/// ```
class NamespacedGeneratedCacheStorage implements GeneratedCacheStorage {
  NamespacedGeneratedCacheStorage({
    required GeneratedCacheStorage inner,
    required String namespace,
  })  : _inner = inner,
        _namespace = _normalizeNamespace(namespace) {
    if (_namespace.isEmpty) {
      throw ArgumentError.value(
        namespace,
        'namespace',
        'Namespace must not be empty.',
      );
    }
  }

  final GeneratedCacheStorage _inner;
  final String _namespace;

  String get namespace => _namespace;

  @override
  Future<CachedEntityRecord?> readEntity(String entityType, String id) async {
    final record = await _inner.readEntity(_scoped(entityType), id);
    return record == null ? null : _unscopedEntity(record, entityType);
  }

  @override
  Future<void> writeEntity(CachedEntityRecord record) {
    return _inner.writeEntity(_scopedEntity(record));
  }

  @override
  Future<void> deleteEntity(String entityType, String id) {
    return _inner.deleteEntity(_scoped(entityType), id);
  }

  @override
  Future<List<CachedEntityRecord>> readEntitiesByType(
    String entityType,
  ) async {
    final records = await _inner.readEntitiesByType(_scoped(entityType));
    return [
      for (final record in records) _unscopedEntity(record, entityType),
    ];
  }

  @override
  Future<CachedIndexRecord?> readIndex(
    String entityType,
    String indexKey,
  ) async {
    final record = await _inner.readIndex(_scoped(entityType), indexKey);
    return record == null ? null : _unscopedIndex(record, entityType);
  }

  @override
  Future<void> writeIndex(CachedIndexRecord record) {
    return _inner.writeIndex(_scopedIndex(record));
  }

  @override
  Future<void> deleteIndex(String entityType, String indexKey) {
    return _inner.deleteIndex(_scoped(entityType), indexKey);
  }

  @override
  Future<void> clearEntityType(String entityType) {
    return _inner.clearEntityType(_scoped(entityType));
  }

  String _scoped(String entityType) => '$_namespace/$entityType';

  CachedEntityRecord _scopedEntity(CachedEntityRecord record) {
    return CachedEntityRecord(
      entityType: _scoped(record.entityType),
      id: record.id,
      json: record.json,
      updatedAt: record.updatedAt,
      lastAccessedAt: record.lastAccessedAt,
      cacheVersion: record.cacheVersion,
      pendingSync: record.pendingSync,
    );
  }

  CachedEntityRecord _unscopedEntity(
    CachedEntityRecord record,
    String entityType,
  ) {
    return CachedEntityRecord(
      entityType: entityType,
      id: record.id,
      json: record.json,
      updatedAt: record.updatedAt,
      lastAccessedAt: record.lastAccessedAt,
      cacheVersion: record.cacheVersion,
      pendingSync: record.pendingSync,
    );
  }

  CachedIndexRecord _scopedIndex(CachedIndexRecord record) {
    return CachedIndexRecord(
      entityType: _scoped(record.entityType),
      indexKey: record.indexKey,
      ids: record.ids,
      updatedAt: record.updatedAt,
      ttl: record.ttl,
      cacheVersion: record.cacheVersion,
    );
  }

  CachedIndexRecord _unscopedIndex(
    CachedIndexRecord record,
    String entityType,
  ) {
    return CachedIndexRecord(
      entityType: entityType,
      indexKey: record.indexKey,
      ids: record.ids,
      updatedAt: record.updatedAt,
      ttl: record.ttl,
      cacheVersion: record.cacheVersion,
    );
  }

  static String _normalizeNamespace(String namespace) {
    return namespace
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .join('/');
  }
}
