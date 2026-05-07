import 'package:riverpod_for_serverpod_runtime/src/cache/generated_key_value_storage.dart';

class MemoryGeneratedKeyValueStorage implements GeneratedKeyValueStorage {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<List<String>> keysWithPrefix(String prefix) async {
    return [
      for (final key in _values.keys)
        if (key.startsWith(prefix)) key,
    ];
  }
}
