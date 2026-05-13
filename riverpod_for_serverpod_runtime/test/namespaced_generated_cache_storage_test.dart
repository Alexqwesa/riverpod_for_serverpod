import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('NamespacedGeneratedCacheStorage', () {
    test('isolates entity records by namespace', () async {
      final inner = MemoryGeneratedCacheStorage();
      final userA = NamespacedGeneratedCacheStorage(
        inner: inner,
        namespace: 'user/a',
      );
      final userB = NamespacedGeneratedCacheStorage(
        inner: inner,
        namespace: 'user/b',
      );

      await userA.writeEntity(
        CachedEntityRecord(
          entityType: 'UserSummary',
          id: '1',
          json: const {'id': 1, 'name': 'A'},
          updatedAt: DateTime.utc(2026),
          cacheVersion: 1,
        ),
      );

      expect(await userB.readEntity('UserSummary', '1'), isNull);

      final fromA = await userA.readEntity('UserSummary', '1');
      expect(fromA, isNotNull);
      expect(fromA!.entityType, 'UserSummary');
      expect(fromA.json['name'], 'A');
    });

    test('isolates index records by namespace', () async {
      final inner = MemoryGeneratedCacheStorage();
      final userA = NamespacedGeneratedCacheStorage(
        inner: inner,
        namespace: '/user/a/',
      );
      final userB = NamespacedGeneratedCacheStorage(
        inner: inner,
        namespace: 'user/b',
      );

      await userA.writeIndex(
        CachedIndexRecord(
          entityType: 'UserSummary',
          indexKey: 'list',
          ids: const ['1'],
          updatedAt: DateTime.utc(2026),
          ttl: const Duration(minutes: 3),
          cacheVersion: 1,
        ),
      );

      expect(await userB.readIndex('UserSummary', 'list'), isNull);

      final fromA = await userA.readIndex('UserSummary', 'list');
      expect(fromA, isNotNull);
      expect(fromA!.entityType, 'UserSummary');
      expect(fromA.ids, ['1']);
    });

    test('clearEntityType clears only the scoped entity type', () async {
      final inner = MemoryGeneratedCacheStorage();
      final userA = NamespacedGeneratedCacheStorage(
        inner: inner,
        namespace: 'user/a',
      );
      final userB = NamespacedGeneratedCacheStorage(
        inner: inner,
        namespace: 'user/b',
      );

      for (final storage in [userA, userB]) {
        await storage.writeEntity(
          CachedEntityRecord(
            entityType: 'UserSummary',
            id: '1',
            json: const {'id': 1},
            updatedAt: DateTime.utc(2026),
            cacheVersion: 1,
          ),
        );
      }

      await userA.clearEntityType('UserSummary');

      expect(await userA.readEntity('UserSummary', '1'), isNull);
      expect(await userB.readEntity('UserSummary', '1'), isNotNull);
    });

    test('rejects empty namespace', () {
      expect(
        () => NamespacedGeneratedCacheStorage(
          inner: MemoryGeneratedCacheStorage(),
          namespace: '///',
        ),
        throwsArgumentError,
      );
    });
  });
}
