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

Or use the setup helper:

```dart
final cacheStorage = await openHiveGeneratedCacheStorage(
  boxName: 'generated_cache',
);
```

For encrypted cache storage, pass a 32-byte Hive AES key:

```dart
final cacheStorage = await openHiveGeneratedCacheStorage(
  boxName: 'generated_secure_cache',
  encryptionKey: key,
);
```

For user-scoped secure cache, keep the key-value storage so the namespace can be
cleared on logout:

```dart
final keyValueStorage = await openHiveGeneratedKeyValueStorage(
  boxName: 'generated_secure_cache',
  encryptionKey: key,
);

final cacheStorage = NamespacedGeneratedCacheStorage(
  inner: JsonGeneratedCacheStorage(keyValueStorage),
  namespace: 'user/$userId',
);

await clearGeneratedCacheNamespace(
  storage: keyValueStorage,
  namespace: 'user/$userId',
);
```
