import 'package:riverpod/riverpod.dart';
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('generated cache storage providers', () {
    test('default normal and secure providers use separate memory stores',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final normal = await container.read(generatedCacheStorageProvider.future);
      final secure =
          await container.read(generatedSecureCacheStorageProvider.future);

      expect(normal, isA<MemoryGeneratedCacheStorage>());
      expect(secure, isA<MemoryGeneratedCacheStorage>());
      expect(identical(normal, secure), isFalse);
    });

    test(
        'secure and plain storage overrides isolate entity writes',
        () async {
      final plain = MemoryGeneratedCacheStorage();
      final secure = MemoryGeneratedCacheStorage();
      final container = ProviderContainer(
        overrides: [
          generatedCacheStorageProvider.overrideWith((ref) async => plain),
          generatedSecureCacheStorageProvider.overrideWith((ref) async => secure),
        ],
      );
      addTearDown(container.dispose);

      final plainStorage = await container.read(generatedCacheStorageProvider.future);
      final secureStorage =
          await container.read(generatedSecureCacheStorageProvider.future);

      final plainCache = GeneratedEntityCache<_TestDoc>(
        storage: plainStorage,
        entityType: 'Note',
        cacheVersion: 1,
        idOf: (e) => e.id,
        toJson: (e) => e.toJson(),
        fromJson: _TestDoc.fromJson,
      );
      final secureCache = GeneratedEntityCache<_TestDoc>(
        storage: secureStorage,
        entityType: 'Note',
        cacheVersion: 1,
        idOf: (e) => e.id,
        toJson: (e) => e.toJson(),
        fromJson: _TestDoc.fromJson,
      );

      await plainCache.putOne(_TestDoc(1, 'plain-only'));
      await secureCache.putOne(_TestDoc(1, 'secure-only'));

      expect((await plainCache.getById(1))!.title, 'plain-only');
      expect((await secureCache.getById(1))!.title, 'secure-only');
    });

    test('can be overridden by apps', () async {
      final storage = MemoryGeneratedCacheStorage();
      final container = ProviderContainer(
        overrides: [
          generatedCacheStorageProvider.overrideWith((ref) async => storage),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(generatedCacheStorageProvider.future),
        same(storage),
      );
    });
  });
}

class _TestDoc {
  _TestDoc(this.id, this.title);

  final int id;
  final String title;

  Map<String, Object?> toJson() => {'id': id, 'title': title};

  static _TestDoc fromJson(Map<String, Object?> json) {
    return _TestDoc(json['id']! as int, json['title']! as String);
  }
}
