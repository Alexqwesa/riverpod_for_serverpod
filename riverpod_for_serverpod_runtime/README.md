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
- `MemoryGeneratedKeyValueStorage` is a test-friendly key-value backend for the
  JSON adapter.

`GeneratedEntityCache<T>` supports optional `maxItems` LRU eviction. Pending-sync
records are not evicted automatically. List reads return only fresh indexes by
default, and can opt into stale reads with `allowStale: true` or
`readStaleList()` for offline fallback after a refresh fails.

Cache records expose `toJson`/`fromJson` so persistent storage adapters can store
records as JSON strings. Timestamps are encoded as ISO-8601 strings and TTL is
encoded as microseconds.
