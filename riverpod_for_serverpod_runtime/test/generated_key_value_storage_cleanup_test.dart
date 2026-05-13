import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('GeneratedKeyValueStorageCleanup', () {
    test('deleteKeysWithPrefix deletes matching keys only', () async {
      final storage = MemoryGeneratedKeyValueStorage();
      await storage.write('entity/user/a/User/1', 'a');
      await storage.write('entity/user/a/User/2', 'b');
      await storage.write('entity/user/b/User/1', 'c');

      await storage.deleteKeysWithPrefix('entity/user/a/');

      expect(await storage.read('entity/user/a/User/1'), isNull);
      expect(await storage.read('entity/user/a/User/2'), isNull);
      expect(await storage.read('entity/user/b/User/1'), 'c');
    });

    test('clearGeneratedCacheNamespace clears entity and index records',
        () async {
      final storage = MemoryGeneratedKeyValueStorage();
      await storage.write('entity/user/a/User/1', 'entity-a');
      await storage.write('index/user/a/User/list', 'index-a');
      await storage.write('entity/user/b/User/1', 'entity-b');
      await storage.write('index/user/b/User/list', 'index-b');

      await clearGeneratedCacheNamespace(
        storage: storage,
        namespace: '/user/a/',
      );

      expect(await storage.read('entity/user/a/User/1'), isNull);
      expect(await storage.read('index/user/a/User/list'), isNull);
      expect(await storage.read('entity/user/b/User/1'), 'entity-b');
      expect(await storage.read('index/user/b/User/list'), 'index-b');
    });

    test('clearGeneratedCacheNamespace rejects empty namespace', () {
      expect(
        () => clearGeneratedCacheNamespace(
          storage: MemoryGeneratedKeyValueStorage(),
          namespace: '///',
        ),
        throwsArgumentError,
      );
    });
  });
}
