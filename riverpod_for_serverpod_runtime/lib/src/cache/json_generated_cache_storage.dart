import 'dart:convert';

import 'package:riverpod_for_serverpod_runtime/src/cache/cached_entity_record.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/cached_index_record.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/generated_cache_storage.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/generated_key_value_storage.dart';

class JsonGeneratedCacheStorage implements GeneratedCacheStorage {
  final GeneratedKeyValueStorage storage;

  const JsonGeneratedCacheStorage(this.storage);

  @override
  Future<CachedEntityRecord?> readEntity(String entityType, String id) async {
    final raw = await storage.read(
      CachedEntityRecord.storageKeyFor(entityType, id),
    );
    if (raw == null) return null;
    return CachedEntityRecord.fromJson(_decodeObject(raw));
  }

  @override
  Future<void> writeEntity(CachedEntityRecord record) async {
    await storage.write(record.storageKey, jsonEncode(record.toJson()));
  }

  @override
  Future<void> deleteEntity(String entityType, String id) async {
    await storage.delete(CachedEntityRecord.storageKeyFor(entityType, id));
  }

  @override
  Future<List<CachedEntityRecord>> readEntitiesByType(String entityType) async {
    final keys = await storage.keysWithPrefix('entity/$entityType/');
    final records = <CachedEntityRecord>[];
    for (final key in keys) {
      final raw = await storage.read(key);
      if (raw == null) continue;
      records.add(CachedEntityRecord.fromJson(_decodeObject(raw)));
    }
    return records;
  }

  @override
  Future<CachedIndexRecord?> readIndex(
    String entityType,
    String indexKey,
  ) async {
    final raw = await storage.read(
      CachedIndexRecord.storageKeyFor(entityType, indexKey),
    );
    if (raw == null) return null;
    return CachedIndexRecord.fromJson(_decodeObject(raw));
  }

  @override
  Future<void> writeIndex(CachedIndexRecord record) async {
    await storage.write(record.storageKey, jsonEncode(record.toJson()));
  }

  @override
  Future<void> deleteIndex(String entityType, String indexKey) async {
    await storage.delete(CachedIndexRecord.storageKeyFor(entityType, indexKey));
  }

  @override
  Future<void> clearEntityType(String entityType) async {
    final entityKeys = await storage.keysWithPrefix('entity/$entityType/');
    final indexKeys = await storage.keysWithPrefix('index/$entityType/');
    for (final key in [...entityKeys, ...indexKeys]) {
      await storage.delete(key);
    }
  }
}

Map<String, Object?> _decodeObject(String raw) {
  return Map<String, Object?>.from(jsonDecode(raw) as Map);
}
