import 'package:riverpod/riverpod.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/generated_cache_storage.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/memory_generated_cache_storage.dart';

/// Default storage used by generated cached-query providers.
///
/// Production apps should usually override this provider with a persistent
/// adapter such as the Hive storage package. The in-memory default keeps
/// generated code usable in tests and demos without extra setup.
final generatedCacheStorageProvider =
    FutureProvider<GeneratedCacheStorage>((ref) async {
  return MemoryGeneratedCacheStorage();
});

/// Default storage used by generated cached-query providers for `secure: true`.
///
/// Override this with encrypted or user-scoped storage when secure cached
/// queries are enabled in an application.
final generatedSecureCacheStorageProvider =
    FutureProvider<GeneratedCacheStorage>((ref) async {
  return MemoryGeneratedCacheStorage();
});
