import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod_for_serverpod_generator/src/generator.dart';
import 'package:yaml/yaml.dart';

Future<void> main(List<String> args) async {
  final serverDir = Directory.current;
  final pubspecFile = File(p.join(serverDir.path, 'pubspec.yaml'));

  if (!await pubspecFile.exists()) {
    stderr.writeln('Missing pubspec.yaml in ${serverDir.path}.');
    exitCode = 1;
    return;
  }

  final pubspec = loadYaml(await pubspecFile.readAsString()) as YamlMap;
  final serverPackageName = (pubspec['name'] as String?)?.trim();
  if (serverPackageName == null || serverPackageName.isEmpty) {
    stderr.writeln('Unable to determine server package name from pubspec.yaml.');
    exitCode = 1;
    return;
  }

  final clientPackageName = deriveClientPackageName(serverPackageName);
  final sourceFile = File(
    p.join(serverDir.path, 'lib', 'src', 'generated', 'ref_endpoints.dart'),
  );
  final targetFile = File(
    p.join(serverDir.parent.path, clientPackageName, 'lib', 'ref_endpoints.dart'),
  );

  if (!await sourceFile.exists()) {
    stderr.writeln(
      'Generated file not found: ${sourceFile.path}. '
      'Run build_runner first.',
    );
    exitCode = 1;
    return;
  }

  await targetFile.parent.create(recursive: true);

  final sourceText = await sourceFile.readAsString();
  if (await targetFile.exists()) {
    final targetText = await targetFile.readAsString();
    if (targetText == sourceText) {
      stdout.writeln('ref_endpoints.dart already up to date at ${targetFile.path}.');
      return;
    }
  }

  await targetFile.writeAsString(sourceText);
  stdout.writeln('Copied ref_endpoints.dart to ${targetFile.path}.');
}
