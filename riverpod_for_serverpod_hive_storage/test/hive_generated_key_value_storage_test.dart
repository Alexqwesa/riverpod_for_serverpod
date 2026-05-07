import 'dart:io';

import 'package:hive/hive.dart';
import 'package:riverpod_for_serverpod_hive_storage/riverpod_for_serverpod_hive_storage.dart';
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('HiveGeneratedKeyValueStorage', () {
    late Directory tempDir;
    late Box<String> box;
    late HiveGeneratedKeyValueStorage storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rfsp_hive_test_');
      Hive.init(tempDir.path);
      box = await Hive.openBox<String>('cache');
      storage = HiveGeneratedKeyValueStorage(box);
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('cache');
      await tempDir.delete(recursive: true);
    });

    test('reads, writes, deletes, and lists by prefix', () async {
      await storage.write('entity/User/1', 'alex');
      await storage.write('entity/User/2', 'sam');
      await storage.write('entity/Role/1', 'admin');

      expect(await storage.read('entity/User/1'), 'alex');
      expect(
        await storage.keysWithPrefix('entity/User/'),
        ['entity/User/1', 'entity/User/2'],
      );

      await storage.delete('entity/User/1');

      expect(await storage.read('entity/User/1'), isNull);
    });

    test('works with JsonGeneratedCacheStorage', () async {
      final jsonStorage = JsonGeneratedCacheStorage(storage);
      final cache = GeneratedEntityCache<_User>(
        storage: jsonStorage,
        entityType: 'User',
        cacheVersion: 1,
        idOf: (user) => user.id,
        toJson: (user) => user.toJson(),
        fromJson: _User.fromJson,
      );

      await cache.putList(
        'all',
        const [
          _User(id: 1, name: 'Alex'),
          _User(id: 2, name: 'Sam'),
        ],
        ttl: const Duration(minutes: 3),
      );

      final users = await cache.readList('all');

      expect(users, isNotNull);
      expect(users!.map((user) => user.name), ['Alex', 'Sam']);
    });
  });
}

class _User {
  final int id;
  final String name;

  const _User({required this.id, required this.name});

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
      };

  static _User fromJson(Map<String, Object?> json) {
    return _User(
      id: json['id']! as int,
      name: json['name']! as String,
    );
  }
}
