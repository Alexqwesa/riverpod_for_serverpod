import 'dart:io';

import 'package:hive/hive.dart';
import 'package:riverpod_for_serverpod_hive_storage/riverpod_for_serverpod_hive_storage.dart';
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('openHiveGeneratedKeyValueStorage', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rfsp_hive_open_test_');
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('opens a plain Hive key-value storage', () async {
      final storage = await openHiveGeneratedKeyValueStorage(
        boxName: 'plain_cache',
        path: tempDir.path,
      );

      await storage.write('key', 'value');

      expect(await storage.read('key'), 'value');
    });

    test('opens an encrypted Hive key-value storage', () async {
      final storage = await openHiveGeneratedKeyValueStorage(
        boxName: 'secure_cache',
        path: tempDir.path,
        encryptionKey: List<int>.filled(32, 7),
      );

      await storage.write('key', 'secret');

      expect(await storage.read('key'), 'secret');
    });

    test('opens a high-level JSON cache storage', () async {
      final storage = await openHiveGeneratedCacheStorage(
        boxName: 'json_cache',
        path: tempDir.path,
      );

      expect(storage, isA<JsonGeneratedCacheStorage>());
    });

    test('rejects duplicate encryption configuration', () async {
      expect(
        () => openHiveGeneratedKeyValueStorage(
          boxName: 'invalid_cache',
          path: tempDir.path,
          encryptionCipher: HiveAesCipher(List<int>.filled(32, 1)),
          encryptionKey: List<int>.filled(32, 2),
        ),
        throwsArgumentError,
      );
    });
  });
}
