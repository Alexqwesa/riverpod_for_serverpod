import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod_for_serverpod_generator/src/ensure_dependencies.dart';
import 'package:riverpod_for_serverpod_generator/src/riverpod_pubspec.dart';
import 'package:riverpod_for_serverpod_generator/src/serverpod_packages.dart';
import 'package:test/test.dart';

void main() {
  group('inferEmitProviderRetry', () {
    test('true when no riverpod constraint', () {
      expect(
        inferEmitProviderRetry('''
name: x
dependencies:
  meta: any
'''),
        isTrue,
      );
    });

    test('false when only Riverpod 2 caret constraint', () {
      expect(
        inferEmitProviderRetry('''
dependencies:
  riverpod: ^2.6.1
'''),
        isFalse,
      );
    });

    test('true when constraint allows 3.0.0', () {
      expect(
        inferEmitProviderRetry('''
dependencies:
  riverpod: ">=2.0.0 <5.0.0"
'''),
        isTrue,
      );
    });

    test('true when flutter_riverpod allows 3', () {
      expect(
        inferEmitProviderRetry('''
dependencies:
  flutter_riverpod: ^3.0.0
'''),
        isTrue,
      );
    });

    test('any listed dep allowing v3 wins over a v2-only dep', () {
      expect(
        inferEmitProviderRetry('''
dependencies:
  riverpod: ^2.0.0
dev_dependencies:
  riverpod: ^3.0.0
'''),
        isTrue,
      );
    });
  });

  group('resolveEmitProviderRetry', () {
    late Directory root;
    late Directory serverDir;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('rfs_pubspec_');
      serverDir = Directory(p.join(root.path, 'demo_server'));
      await serverDir.create();
      await File(p.join(serverDir.path, 'pubspec.yaml')).writeAsString('''
name: demo_server
dependencies:
  meta: any
''');
    });

    tearDown(() async {
      await root.delete(recursive: true);
    });

    test('prefers flutter_riverpod from *_flutter over server', () async {
      final flutterDir = Directory(p.join(root.path, 'demo_flutter'));
      await flutterDir.create();
      await File(p.join(flutterDir.path, 'pubspec.yaml')).writeAsString('''
name: demo_flutter
dependencies:
  flutter_riverpod: ^2.6.1
''');

      expect(
        await resolveEmitProviderRetry(
          serverDir: serverDir,
          serverPackageName: 'demo_server',
          serverPubspecYaml: '''
name: demo_server
dependencies:
  riverpod: ^3.0.0
''',
        ),
        isFalse,
      );
    });

    test('falls back to client when flutter has no riverpod dep', () async {
      final flutterDir = Directory(p.join(root.path, 'demo_flutter'));
      await flutterDir.create();
      await File(p.join(flutterDir.path, 'pubspec.yaml')).writeAsString('''
name: demo_flutter
dependencies:
  flutter:
    sdk: flutter
''');

      final clientDir = Directory(p.join(root.path, 'demo_client'));
      await clientDir.create();
      await File(p.join(clientDir.path, 'pubspec.yaml')).writeAsString('''
name: demo_client
dependencies:
  riverpod: ^2.6.1
''');

      expect(
        await resolveEmitProviderRetry(
          serverDir: serverDir,
          serverPackageName: 'demo_server',
          serverPubspecYaml: 'name: demo_server\n',
        ),
        isFalse,
      );
    });

    test('defaults to Riverpod 3 when no sibling constraints', () async {
      expect(
        await resolveEmitProviderRetry(
          serverDir: serverDir,
          serverPackageName: 'demo_server',
          serverPubspecYaml: 'name: demo_server\n',
        ),
        isTrue,
      );
    });
  });

  group('preferredRiverpodConstraint', () {
    test('reads flutter_riverpod before client riverpod', () {
      expect(
        preferredRiverpodConstraint(
          flutterPubspecYaml: '''
dependencies:
  flutter_riverpod: ^2.6.1
''',
          clientPubspecYaml: '''
dependencies:
  riverpod: ^3.0.0
''',
        ),
        '^2.6.1',
      );
    });
  });

  group('ensureServerpodTrioDependencies', () {
    late Directory root;
    late Directory serverDir;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('rfs_ensure_');
      serverDir = Directory(p.join(root.path, 'demo_server'));
      await serverDir.create();
      await File(p.join(serverDir.path, 'pubspec.yaml')).writeAsString('''
name: demo_server
dependencies:
  serverpod: 3.4.4
dev_dependencies:
  lints: any
''');

      final clientDir = Directory(p.join(root.path, 'demo_client'));
      await clientDir.create(recursive: true);
      await Directory(p.join(clientDir.path, 'lib')).create();
      await File(p.join(clientDir.path, 'pubspec.yaml')).writeAsString('''
name: demo_client
dependencies:
  serverpod_client: 3.4.4
''');
      await File(p.join(clientDir.path, 'lib', 'demo_client.dart'))
          .writeAsString("library;\n");

      final flutterDir = Directory(p.join(root.path, 'demo_flutter'));
      await flutterDir.create();
      await File(p.join(flutterDir.path, 'pubspec.yaml')).writeAsString('''
name: demo_flutter
dependencies:
  flutter:
    sdk: flutter
''');
    });

    tearDown(() async {
      await root.delete(recursive: true);
    });

    test('fills missing trio dependencies and client export', () async {
      final added = await ensureServerpodTrioDependencies(
        serverDir: serverDir,
        serverPackageName: 'demo_server',
      );

      expect(
        added.map((e) => '${p.basename(e.packagePath)}:${e.name}'),
        containsAll([
          'demo_server:riverpod_for_serverpod_annotation',
          'demo_server:riverpod_for_serverpod_generator',
          'demo_server:build_runner',
          'demo_client:riverpod',
          'demo_client:riverpod_for_serverpod_runtime',
          'demo_client:serverpod_auth_client',
          'demo_flutter:flutter_riverpod',
        ]),
      );

      final clientPubspec =
          await File(p.join(root.path, 'demo_client', 'pubspec.yaml'))
              .readAsString();
      expect(clientPubspec, contains('riverpod:'));
      expect(clientPubspec, contains('serverpod_auth_client: 3.4.4'));

      final clientLib =
          await File(p.join(root.path, 'demo_client', 'lib', 'demo_client.dart'))
              .readAsString();
      expect(clientLib, contains("export 'ref_endpoints.dart';"));

      final again = await ensureServerpodTrioDependencies(
        serverDir: serverDir,
        serverPackageName: 'demo_server',
      );
      expect(again, isEmpty);
    });
  });

  group('deriveFlutterPackageName', () {
    test('maps *_server to *_flutter', () {
      expect(deriveFlutterPackageName('demo_server'), 'demo_flutter');
      expect(deriveClientPackageName('demo_server'), 'demo_client');
    });
  });
}
