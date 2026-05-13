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
