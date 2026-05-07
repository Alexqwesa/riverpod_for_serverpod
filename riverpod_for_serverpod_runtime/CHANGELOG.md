## 3.0.0

- Added the initial runtime cache package foundation.
- Added optional `maxItems` LRU eviction for entity records while preserving pending-sync records.
- Added JSON round-trip support for cached entity and index records.
- Added `JsonGeneratedCacheStorage` over a string key-value storage interface to prepare for Hive and other persistent adapters.
