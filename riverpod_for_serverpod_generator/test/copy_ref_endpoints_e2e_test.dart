import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Process-level e2e for `bin/copy_ref_endpoints.dart`.
void main() {
  late Directory root;
  late Directory serverDir;
  late File sourceFile;
  late File targetFile;
  late String scriptPath;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('rfs_copy_e2e_');
    serverDir = Directory(p.join(root.path, 'demo_server'));
    await serverDir.create();
    await Directory(p.join(serverDir.path, 'lib', 'src', 'generated'))
        .create(recursive: true);

    await File(p.join(serverDir.path, 'pubspec.yaml')).writeAsString('''
name: demo_server
environment:
  sdk: ^3.0.0
dependencies:
  serverpod: 3.4.4
''');

    final clientDir = Directory(p.join(root.path, 'demo_client'));
    await Directory(p.join(clientDir.path, 'lib')).create(recursive: true);
    await File(p.join(clientDir.path, 'pubspec.yaml')).writeAsString('''
name: demo_client
environment:
  sdk: ^3.0.0
dependencies:
  serverpod_client: 3.4.4
''');

    sourceFile = File(
      p.join(serverDir.path, 'lib', 'src', 'generated', 'ref_endpoints.dart'),
    );
    targetFile = File(p.join(clientDir.path, 'lib', 'ref_endpoints.dart'));
    await sourceFile.writeAsString('// e2e generated content\n');

    scriptPath = p.join(
      _generatorPackageRoot(),
      'bin',
      'copy_ref_endpoints.dart',
    );
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('copies generated ref_endpoints into sibling client package', () async {
    final first = await Process.run(
      Platform.resolvedExecutable,
      [scriptPath, '--no-ensure-deps'],
      workingDirectory: serverDir.path,
    );
    expect(first.exitCode, 0, reason: first.stderr.toString());
    expect(first.stdout.toString(), contains('Copied ref_endpoints.dart'));
    expect(await targetFile.readAsString(), '// e2e generated content\n');

    final second = await Process.run(
      Platform.resolvedExecutable,
      [scriptPath, '--no-ensure-deps'],
      workingDirectory: serverDir.path,
    );
    expect(second.exitCode, 0, reason: second.stderr.toString());
    expect(second.stdout.toString(), contains('already up to date'));
  });

  test('fails clearly when generated source is missing', () async {
    await sourceFile.delete();
    final result = await Process.run(
      Platform.resolvedExecutable,
      [scriptPath, '--no-ensure-deps'],
      workingDirectory: serverDir.path,
    );
    expect(result.exitCode, isNonZero);
    expect(result.stderr.toString(), contains('Generated file not found'));
  });
}

String _generatorPackageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final bin = File(p.join(dir.path, 'bin', 'copy_ref_endpoints.dart'));
    if (bin.existsSync()) return dir.path;
    final nested = File(
      p.join(
        dir.path,
        'riverpod_for_serverpod_generator',
        'bin',
        'copy_ref_endpoints.dart',
      ),
    );
    if (nested.existsSync()) {
      return p.join(dir.path, 'riverpod_for_serverpod_generator');
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Could not locate riverpod_for_serverpod_generator package root.');
}
