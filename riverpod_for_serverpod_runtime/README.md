# riverpod_for_serverpod_runtime

Runtime cache primitives used by generated Riverpod providers for Serverpod
endpoints.

This package is intentionally storage-agnostic. Generated code talks to
`GeneratedCacheStorage`; apps can use memory storage in tests and Hive or another
persistent adapter in production.
