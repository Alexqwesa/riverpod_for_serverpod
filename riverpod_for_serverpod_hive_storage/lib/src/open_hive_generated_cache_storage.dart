import 'package:hive/hive.dart';
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';

import 'hive_generated_key_value_storage.dart';

Future<HiveGeneratedKeyValueStorage> openHiveGeneratedKeyValueStorage({
  String boxName = 'generated_cache',
  String? path,
  HiveCipher? encryptionCipher,
  List<int>? encryptionKey,
}) async {
  if (encryptionCipher != null && encryptionKey != null) {
    throw ArgumentError(
      'Provide either encryptionCipher or encryptionKey, not both.',
    );
  }

  final box = await Hive.openBox<String>(
    boxName,
    path: path,
    encryptionCipher:
        encryptionCipher ?? _cipherFromEncryptionKey(encryptionKey),
  );

  return HiveGeneratedKeyValueStorage(box);
}

Future<JsonGeneratedCacheStorage> openHiveGeneratedCacheStorage({
  String boxName = 'generated_cache',
  String? path,
  HiveCipher? encryptionCipher,
  List<int>? encryptionKey,
}) async {
  final keyValueStorage = await openHiveGeneratedKeyValueStorage(
    boxName: boxName,
    path: path,
    encryptionCipher: encryptionCipher,
    encryptionKey: encryptionKey,
  );

  return JsonGeneratedCacheStorage(keyValueStorage);
}

HiveCipher? _cipherFromEncryptionKey(List<int>? encryptionKey) {
  if (encryptionKey == null) {
    return null;
  }

  return HiveAesCipher(encryptionKey);
}
