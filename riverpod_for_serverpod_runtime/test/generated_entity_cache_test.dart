import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

class TestUser {
  final int id;
  final String name;

  const TestUser({required this.id, required this.name});

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  static TestUser fromJson(Map<String, Object?> json) {
    return TestUser(id: json['id']! as int, name: json['name']! as String);
  }
}

void main() {
  group('GeneratedEntityCache', () {
    late DateTime now;
    late MemoryGeneratedCacheStorage storage;
    late GeneratedEntityCache<TestUser> cache;

    setUp(() {
      now = DateTime(2026, 1, 1, 12);
      storage = MemoryGeneratedCacheStorage();
      cache = GeneratedEntityCache<TestUser>(
        storage: storage,
        entityType: 'TestUser',
        cacheVersion: 1,
        idOf: (user) => user.id,
        toJson: (user) => user.toJson(),
        fromJson: TestUser.fromJson,
        now: () => now,
      );
    });

    test('putOne/getById stores and reads one entity', () async {
      await cache.putOne(const TestUser(id: 1, name: 'Alex'));

      final user = await cache.getById(1);

      expect(user, isNotNull);
      expect(user!.name, 'Alex');
    });

    test('putList/readList stores entities and index', () async {
      await cache.putList(
          'listUsers',
          const [
            TestUser(id: 1, name: 'Alex'),
            TestUser(id: 2, name: 'Sam'),
          ],
          ttl: const Duration(minutes: 3));

      final users = await cache.readList('listUsers');

      expect(users, isNotNull);
      expect(users!.map((user) => user.name), ['Alex', 'Sam']);
    });

    test('readList returns null when index is expired', () async {
      await cache.putList(
          'listUsers',
          const [
            TestUser(id: 1, name: 'Alex'),
          ],
          ttl: const Duration(minutes: 3));

      now = now.add(const Duration(minutes: 4));

      expect(await cache.readList('listUsers'), isNull);
    });

    test(
      'cacheVersion mismatch ignores old entity and index records',
      () async {
        await cache.putList(
            'listUsers',
            const [
              TestUser(id: 1, name: 'Alex'),
            ],
            ttl: const Duration(minutes: 3));

        final nextVersionCache = GeneratedEntityCache<TestUser>(
          storage: storage,
          entityType: 'TestUser',
          cacheVersion: 2,
          idOf: (user) => user.id,
          toJson: (user) => user.toJson(),
          fromJson: TestUser.fromJson,
          now: () => now,
        );

        expect(await nextVersionCache.getById(1), isNull);
        expect(await nextVersionCache.readList('listUsers'), isNull);
      },
    );

    test('pendingSync is persisted on entity records', () async {
      await cache.putOne(
        const TestUser(id: 1, name: 'Alex'),
        pendingSync: true,
      );

      final record = await storage.readEntity('TestUser', '1');

      expect(record, isNotNull);
      expect(record!.pendingSync, isTrue);
    });

    test('evicts least recently used non-pending records over maxItems',
        () async {
      cache = GeneratedEntityCache<TestUser>(
        storage: storage,
        entityType: 'TestUser',
        cacheVersion: 1,
        maxItems: 2,
        idOf: (user) => user.id,
        toJson: (user) => user.toJson(),
        fromJson: TestUser.fromJson,
        now: () => now,
      );

      await cache.putOne(const TestUser(id: 1, name: 'Alex'));
      now = now.add(const Duration(minutes: 1));
      await cache.putOne(const TestUser(id: 2, name: 'Sam'));
      now = now.add(const Duration(minutes: 1));
      await cache.getById(1);
      now = now.add(const Duration(minutes: 1));
      await cache.putOne(const TestUser(id: 3, name: 'Taylor'));

      expect(await cache.getById(1), isNotNull);
      expect(await cache.getById(2), isNull);
      expect(await cache.getById(3), isNotNull);
    });

    test('does not evict pendingSync records', () async {
      cache = GeneratedEntityCache<TestUser>(
        storage: storage,
        entityType: 'TestUser',
        cacheVersion: 1,
        maxItems: 1,
        idOf: (user) => user.id,
        toJson: (user) => user.toJson(),
        fromJson: TestUser.fromJson,
        now: () => now,
      );

      await cache.putOne(
        const TestUser(id: 1, name: 'Alex'),
        pendingSync: true,
      );
      now = now.add(const Duration(minutes: 1));
      await cache.putOne(const TestUser(id: 2, name: 'Sam'));

      expect(await cache.getById(1), isNotNull);
      expect(await cache.getById(2), isNull);
    });

    test('throws when maxItems is invalid during eviction', () async {
      final invalidCache = GeneratedEntityCache<TestUser>(
        storage: storage,
        entityType: 'TestUser',
        cacheVersion: 1,
        maxItems: 0,
        idOf: (user) => user.id,
        toJson: (user) => user.toJson(),
        fromJson: TestUser.fromJson,
      );

      expect(
        () => invalidCache.putOne(const TestUser(id: 1, name: 'Alex')),
        throwsArgumentError,
      );
    });

    test('throws when entity id is null', () async {
      final cacheWithNullId = GeneratedEntityCache<TestUser>(
        storage: storage,
        entityType: 'TestUser',
        cacheVersion: 1,
        idOf: (_) => null,
        toJson: (user) => user.toJson(),
        fromJson: TestUser.fromJson,
      );

      expect(
        () => cacheWithNullId.putOne(const TestUser(id: 1, name: 'Alex')),
        throwsArgumentError,
      );
    });
  });

  group('MemoryGeneratedCacheStorage', () {
    test('clearEntityType removes entities and indexes for one type', () async {
      final storage = MemoryGeneratedCacheStorage();
      await storage.writeEntity(
        CachedEntityRecord(
          entityType: 'User',
          id: '1',
          json: const {'id': 1},
          updatedAt: DateTime(2026),
          lastAccessedAt: DateTime(2026),
          cacheVersion: 1,
        ),
      );
      await storage.writeIndex(
        CachedIndexRecord(
          entityType: 'User',
          indexKey: 'all',
          ids: const ['1'],
          updatedAt: DateTime(2026),
          ttl: const Duration(minutes: 3),
          cacheVersion: 1,
        ),
      );
      await storage.writeEntity(
        CachedEntityRecord(
          entityType: 'Role',
          id: '1',
          json: const {'id': 1},
          updatedAt: DateTime(2026),
          lastAccessedAt: DateTime(2026),
          cacheVersion: 1,
        ),
      );

      await storage.clearEntityType('User');

      expect(await storage.readEntity('User', '1'), isNull);
      expect(await storage.readIndex('User', 'all'), isNull);
      expect(await storage.readEntity('Role', '1'), isNotNull);
    });
  });

  group('cache record JSON', () {
    test('CachedEntityRecord round trips through JSON', () {
      final record = CachedEntityRecord(
        entityType: 'User',
        id: '1',
        json: const {
          'id': 1,
          'name': 'Alex',
          'tags': ['admin', 'operator'],
        },
        updatedAt: DateTime.utc(2026, 1, 1, 12),
        lastAccessedAt: DateTime.utc(2026, 1, 1, 13),
        cacheVersion: 2,
        pendingSync: true,
      );

      final restored = CachedEntityRecord.fromJson(record.toJson());

      expect(restored.entityType, record.entityType);
      expect(restored.id, record.id);
      expect(restored.json, record.json);
      expect(restored.updatedAt, record.updatedAt);
      expect(restored.lastAccessedAt, record.lastAccessedAt);
      expect(restored.cacheVersion, record.cacheVersion);
      expect(restored.pendingSync, isTrue);
    });

    test('CachedIndexRecord round trips through JSON', () {
      final record = CachedIndexRecord(
        entityType: 'User',
        indexKey: 'listUsersByRole(admin)',
        ids: const ['1', '2'],
        updatedAt: DateTime.utc(2026, 1, 1, 12),
        ttl: const Duration(minutes: 3),
        cacheVersion: 2,
      );

      final restored = CachedIndexRecord.fromJson(record.toJson());

      expect(restored.entityType, record.entityType);
      expect(restored.indexKey, record.indexKey);
      expect(restored.ids, record.ids);
      expect(restored.updatedAt, record.updatedAt);
      expect(restored.ttl, record.ttl);
      expect(restored.cacheVersion, record.cacheVersion);
    });
  });
}
