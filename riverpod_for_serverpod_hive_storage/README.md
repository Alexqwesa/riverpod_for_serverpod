# riverpod_for_serverpod_hive_storage

Hive storage adapter for `riverpod_for_serverpod_runtime`.

This package provides a `GeneratedKeyValueStorage` implementation backed by a
Hive `Box<String>`. The core runtime stays storage-agnostic; this adapter is
optional for apps that want Hive persistence.

```dart
final box = await Hive.openBox<String>('generated_cache');
final keyValueStorage = HiveGeneratedKeyValueStorage(box);
final cacheStorage = JsonGeneratedCacheStorage(keyValueStorage);
```
