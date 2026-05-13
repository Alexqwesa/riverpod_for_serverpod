abstract interface class GeneratedKeyValueStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<List<String>> keysWithPrefix(String prefix);
}

extension GeneratedKeyValueStorageCleanup on GeneratedKeyValueStorage {
  Future<void> deleteKeysWithPrefix(String prefix) async {
    final keys = await keysWithPrefix(prefix);
    for (final key in keys) {
      await delete(key);
    }
  }
}

/// Clears all cache records written through [NamespacedGeneratedCacheStorage]
/// for the provided namespace.
///
/// Pass the same namespace used to construct the namespaced storage, for
/// example `user/$userId`.
Future<void> clearGeneratedCacheNamespace({
  required GeneratedKeyValueStorage storage,
  required String namespace,
}) async {
  final normalized =
      namespace.split('/').where((part) => part.trim().isNotEmpty).join('/');

  if (normalized.isEmpty) {
    throw ArgumentError.value(
      namespace,
      'namespace',
      'Namespace must not be empty.',
    );
  }

  await storage.deleteKeysWithPrefix('entity/$normalized/');
  await storage.deleteKeysWithPrefix('index/$normalized/');
}
