import 'package:hive/hive.dart';
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';

class HiveGeneratedKeyValueStorage implements GeneratedKeyValueStorage {
  final Box<String> box;

  const HiveGeneratedKeyValueStorage(this.box);

  @override
  Future<String?> read(String key) async => box.get(key);

  @override
  Future<void> write(String key, String value) async {
    await box.put(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await box.delete(key);
  }

  @override
  Future<List<String>> keysWithPrefix(String prefix) async {
    return [
      for (final key in box.keys)
        if (key is String && key.startsWith(prefix)) key,
    ];
  }
}
