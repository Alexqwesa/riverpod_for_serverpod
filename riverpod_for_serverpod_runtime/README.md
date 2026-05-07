# riverpod_for_serverpod_runtime

Runtime cache primitives used by generated Riverpod providers for Serverpod
endpoints.

This package is intentionally storage-agnostic. Generated code talks to
`GeneratedCacheStorage`; apps can use memory storage in tests and Hive or another
persistent adapter in production.

Current primitives:

- `GeneratedEntityCache<T>` stores entities by id and list indexes by query key.
- `CachedEntityRecord` tracks cache version, update time, last access time, and
  `pendingSync`.
- `CachedIndexRecord` tracks index ids, TTL, and cache version.
- `MemoryGeneratedCacheStorage` is useful for tests and non-persistent demos.

`GeneratedEntityCache<T>` supports optional `maxItems` LRU eviction. Pending-sync
records are not evicted automatically.

Cache records expose `toJson`/`fromJson` so persistent storage adapters can store
records as JSON strings. Timestamps are encoded as ISO-8601 strings and TTL is
encoded as microseconds.
