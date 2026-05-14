# riverpod_for_serverpod_runtime

Runtime cache primitives used by generated Riverpod providers for Serverpod
endpoints.

This package is intentionally storage-agnostic. Generated code talks to
`GeneratedCacheStorage`; apps can use memory storage in tests and Hive or another
persistent adapter in production.

Current primitives:

- `EndpointManifest` describes generated endpoints, methods, cached queries,
  mutation commands, validation metadata, and parameters.
- `GeneratedEntityCache<T>` stores entities by id and list indexes by query key.
- `CachedEntityRecord` tracks cache version, update time, last access time, and
  `pendingSync`.
- `CachedIndexRecord` tracks index ids, TTL, and cache version.
- `MemoryGeneratedCacheStorage` is useful for tests and non-persistent demos.
- `JsonGeneratedCacheStorage` stores cache records as JSON strings on top of a
  simple `GeneratedKeyValueStorage`.
- `generatedCacheStorageProvider` and `generatedSecureCacheStorageProvider`
  provide memory-backed defaults for generated cached-query code. Override them
  in apps to use persistent storage.
- `NamespacedGeneratedCacheStorage` scopes entity/index records by namespace,
  which is useful for per-user secure caches.
- `clearGeneratedCacheNamespace` deletes all key-value records in a namespace,
  which is useful during logout.
- `mutationRetryQueueProvider` / `InMemoryMutationRetryQueue` for idempotent
  mutation retries after connection-style failures (used by generated commands).
- `refreshWarningProvider` / `RefreshWarningNotifier` for aggregated failed
  [@CachedQuery] refresh attempts and queued mutation retry warnings.

`GeneratedEntityCache<T>` supports optional `maxItems` LRU eviction. Pending-sync
records are not evicted automatically. List reads return only fresh indexes by
default, and can opt into stale reads with `allowStale: true` or
`readStaleList()` for offline fallback after a refresh fails.

Cache records expose `toJson`/`fromJson` so persistent storage adapters can store
records as JSON strings. Timestamps are encoded as ISO-8601 strings and TTL is
encoded as microseconds.

## Storage Providers

Generated cached-query providers read storage from:

- `generatedCacheStorageProvider`
- `generatedSecureCacheStorageProvider` for `@CachedQuery(secure: true)`

Both default to separate `MemoryGeneratedCacheStorage` instances. Override them
with Hive or another persistent adapter in production.

```dart
final container = ProviderContainer(
  overrides: [
    generatedCacheStorageProvider.overrideWith((ref) async {
      return persistentStorage;
    }),
  ],
);
```

## User-Scoped Cache

Wrap persistent storage with `NamespacedGeneratedCacheStorage` when cache records
must be isolated by user:

```dart
final keyValue = MemoryGeneratedKeyValueStorage();
final storage = NamespacedGeneratedCacheStorage(
  inner: JsonGeneratedCacheStorage(keyValue),
  namespace: 'user/$userId',
);
```

To clear the same namespace on logout:

```dart
await clearGeneratedCacheNamespace(
  storage: keyValue,
  namespace: 'user/$userId',
);
```

## Sync Warnings

`refreshWarningProvider` aggregates cache refresh failures and queued mutation
retries into one state object. Generated mutation commands record a queued
mutation warning when a connection-like failure is eligible for retry. The
default `mutationRetryQueueProvider` keeps `queuedMutationCount` synchronized
after queue schedule, retry, cancel, and clear operations.

```dart
final warning = ref.watch(refreshWarningProvider);

if (warning.hasWarning) {
  final queued = warning.queuedMutationCount;
  final nextRetryAt = warning.nextRetryAt;
}
```
