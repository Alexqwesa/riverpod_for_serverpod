import 'dart:convert';

import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('JsonGeneratedCacheStorage', () {
    late MemoryGeneratedKeyValueStorage keyValue;
    late JsonGeneratedCacheStorage storage;

    setUp(() {
      keyValue = MemoryGeneratedKeyValueStorage();
      storage = JsonGeneratedCacheStorage(keyValue);
    });

    test('stores entity records as JSON strings', () async {
      final record = CachedEntityRecord(
        entityType: 'User',
        id: '1',
        json: const {'id': 1, 'name': 'Alex'},
        updatedAt: DateTime.utc(2026),
        cacheVersion: 1,
        pendingSync: true,
      );

      await storage.writeEntity(record);

      final raw = await keyValue.read(record.storageKey);
      expect(raw, isNotNull);
      expect(jsonDecode(raw!)['pendingSync'], isTrue);

      final restored = await storage.readEntity('User', '1');
      expect(restored, isNotNull);
      expect(restored!.json, record.json);
      expect(restored.pendingSync, isTrue);
    });

    test('stores index records as JSON strings', () async {
      final record = CachedIndexRecord(
        entityType: 'User',
        indexKey: 'all',
        ids: const ['1', '2'],
        updatedAt: DateTime.utc(2026),
        ttl: const Duration(minutes: 3),
        cacheVersion: 1,
      );

      await storage.writeIndex(record);

      final raw = await keyValue.read(record.storageKey);
      expect(raw, isNotNull);
      expect(jsonDecode(raw!)['ttlMicroseconds'], record.ttl.inMicroseconds);

      final restored = await storage.readIndex('User', 'all');
      expect(restored, isNotNull);
      expect(restored!.ids, record.ids);
      expect(restored.ttl, record.ttl);
    });

    test('readEntitiesByType returns only matching entity type', () async {
      await storage.writeEntity(
        CachedEntityRecord(
          entityType: 'User',
          id: '1',
          json: const {'id': 1},
          updatedAt: DateTime.utc(2026),
          cacheVersion: 1,
        ),
      );
      await storage.writeEntity(
        CachedEntityRecord(
          entityType: 'Role',
          id: '1',
          json: const {'id': 1},
          updatedAt: DateTime.utc(2026),
          cacheVersion: 1,
        ),
      );

      final records = await storage.readEntitiesByType('User');

      expect(records, hasLength(1));
      expect(records.single.entityType, 'User');
    });

    test('delete and clear remove expected keys', () async {
      await storage.writeEntity(
        CachedEntityRecord(
          entityType: 'User',
          id: '1',
          json: const {'id': 1},
          updatedAt: DateTime.utc(2026),
          cacheVersion: 1,
        ),
      );
      await storage.writeIndex(
        CachedIndexRecord(
          entityType: 'User',
          indexKey: 'all',
          ids: const ['1'],
          updatedAt: DateTime.utc(2026),
          ttl: const Duration(minutes: 3),
          cacheVersion: 1,
        ),
      );
      await storage.writeEntity(
        CachedEntityRecord(
          entityType: 'Role',
          id: '1',
          json: const {'id': 1},
          updatedAt: DateTime.utc(2026),
          cacheVersion: 1,
        ),
      );

      await storage.deleteEntity('Role', '1');
      await storage.clearEntityType('User');

      expect(await storage.readEntity('Role', '1'), isNull);
      expect(await storage.readEntity('User', '1'), isNull);
      expect(await storage.readIndex('User', 'all'), isNull);
    });
  });

  group('MemoryGeneratedKeyValueStorage', () {
    test('lists keys by prefix', () async {
      final storage = MemoryGeneratedKeyValueStorage();
      await storage.write('entity/User/1', 'a');
      await storage.write('entity/User/2', 'b');
      await storage.write('entity/Role/1', 'c');

      expect(
        await storage.keysWithPrefix('entity/User/'),
        ['entity/User/1', 'entity/User/2'],
      );
    });
  });
}
