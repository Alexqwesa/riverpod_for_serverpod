import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod_for_serverpod_generator/src/riverpod_pubspec.dart';
import 'package:riverpod_for_serverpod_generator/src/serverpod_packages.dart';
import 'package:yaml/yaml.dart';

/// Hosted package line for riverpod_for_serverpod_* packages.
const riverpodForServerpodConstraint = '^3.0.0';

const _defaultRiverpodConstraint = '^3.0.0';
const _defaultBuildRunnerConstraint = '^2.5.0';

class EnsuredDependency {
  final String packagePath;
  final String section;
  final String name;
  final String constraint;

  const EnsuredDependency({
    required this.packagePath,
    required this.section,
    required this.name,
    required this.constraint,
  });

  @override
  String toString() =>
      '${p.basename(packagePath)} $section: $name: $constraint';
}

/// Ensures expected dependencies across the Serverpod trio next to [serverDir].
///
/// Returns dependencies that were added. Existing entries are left unchanged
/// (including path / git deps).
Future<List<EnsuredDependency>> ensureServerpodTrioDependencies({
  required Directory serverDir,
  required String serverPackageName,
  bool write = true,
}) async {
  final added = <EnsuredDependency>[];
  final flutterName = deriveFlutterPackageName(serverPackageName);
  final clientName = deriveClientPackageName(serverPackageName);

  final flutterYaml =
      await readSiblingPubspecYaml(serverDir, flutterName);
  final clientYaml = await readSiblingPubspecYaml(serverDir, clientName);
  final riverpodConstraint = preferredRiverpodConstraint(
        flutterPubspecYaml: flutterYaml,
        clientPubspecYaml: clientYaml,
      ) ??
      _defaultRiverpodConstraint;

  // Server: annotations + generator tooling.
  added.addAll(
    await _ensurePubspecDeps(
      File(p.join(serverDir.path, 'pubspec.yaml')),
      dependencies: {
        'riverpod_for_serverpod_annotation': riverpodForServerpodConstraint,
      },
      devDependencies: {
        'build_runner': _defaultBuildRunnerConstraint,
        'riverpod_for_serverpod_generator': riverpodForServerpodConstraint,
      },
      write: write,
    ),
  );

  // Client: where generated Riverpod code compiles and runs.
  final clientDir = siblingPackageDir(serverDir, clientName);
  if (clientDir != null) {
    final authConstraint = _hostedConstraintFor(
          clientYaml ?? '',
          'serverpod_auth_client',
        ) ??
        _hostedConstraintFor(clientYaml ?? '', 'serverpod_client') ??
        '3.4.4';

    added.addAll(
      await _ensurePubspecDeps(
        File(p.join(clientDir.path, 'pubspec.yaml')),
        dependencies: {
          'riverpod': riverpodConstraint,
          'riverpod_for_serverpod_runtime': riverpodForServerpodConstraint,
          'serverpod_auth_client': authConstraint,
        },
        write: write,
      ),
    );

    if (write) {
      await _ensureClientExportsRefEndpoints(clientDir, clientName);
    }
  }

  // Flutter app: Riverpod binding; Hive storage stays optional.
  final flutterDir = siblingPackageDir(serverDir, flutterName);
  if (flutterDir != null) {
    added.addAll(
      await _ensurePubspecDeps(
        File(p.join(flutterDir.path, 'pubspec.yaml')),
        dependencies: {
          'flutter_riverpod': riverpodConstraint,
        },
        write: write,
      ),
    );
  }

  return added;
}

Future<List<EnsuredDependency>> _ensurePubspecDeps(
  File pubspecFile, {
  Map<String, String> dependencies = const {},
  Map<String, String> devDependencies = const {},
  required bool write,
}) async {
  if (!await pubspecFile.exists()) return const [];
  var text = await pubspecFile.readAsString();
  final added = <EnsuredDependency>[];

  for (final entry in dependencies.entries) {
    final next = _ensureDepInSection(
      text,
      section: 'dependencies',
      name: entry.key,
      constraint: entry.value,
    );
    if (next != null) {
      text = next;
      added.add(
        EnsuredDependency(
          packagePath: pubspecFile.parent.path,
          section: 'dependencies',
          name: entry.key,
          constraint: entry.value,
        ),
      );
    }
  }

  for (final entry in devDependencies.entries) {
    final next = _ensureDepInSection(
      text,
      section: 'dev_dependencies',
      name: entry.key,
      constraint: entry.value,
    );
    if (next != null) {
      text = next;
      added.add(
        EnsuredDependency(
          packagePath: pubspecFile.parent.path,
          section: 'dev_dependencies',
          name: entry.key,
          constraint: entry.value,
        ),
      );
    }
  }

  if (write && added.isNotEmpty) {
    await pubspecFile.writeAsString(text);
  }
  return added;
}

/// Returns updated pubspec text when [name] was missing; otherwise `null`.
String? _ensureDepInSection(
  String pubspecText, {
  required String section,
  required String name,
  required String constraint,
}) {
  final doc = loadYaml(pubspecText);
  if (doc is! YamlMap) return null;
  final map = doc[section];
  if (map is YamlMap && map.containsKey(name)) return null;

  final sectionHeader = RegExp('^$section:\\s*\$', multiLine: true);
  final match = sectionHeader.firstMatch(pubspecText);
  if (match == null) {
    final suffix = pubspecText.endsWith('\n') ? '' : '\n';
    return '$pubspecText$suffix\n$section:\n  $name: $constraint\n';
  }

  final insertAt = match.end;
  final line = '\n  $name: $constraint';
  return pubspecText.substring(0, insertAt) +
      line +
      pubspecText.substring(insertAt);
}

String? _hostedConstraintFor(String pubspecYaml, String packageName) {
  if (pubspecYaml.isEmpty) return null;
  final doc = loadYaml(pubspecYaml);
  if (doc is! YamlMap) return null;
  for (final sectionName in ['dependencies', 'dev_dependencies']) {
    final section = doc[sectionName];
    if (section is! YamlMap) continue;
    final c = constraintStringFromDepValue(section[packageName]);
    if (c != null) return c;
  }
  return null;
}

Future<void> _ensureClientExportsRefEndpoints(
  Directory clientDir,
  String clientPackageName,
) async {
  final candidates = [
    File(p.join(clientDir.path, 'lib', '$clientPackageName.dart')),
    File(p.join(clientDir.path, 'lib', 'client.dart')),
  ];
  for (final file in candidates) {
    if (!await file.exists()) continue;
    final text = await file.readAsString();
    if (text.contains("ref_endpoints.dart")) return;
    final exportLine = "export 'ref_endpoints.dart';\n";
    final updated = text.endsWith('\n') ? '$text$exportLine' : '$text\n$exportLine';
    await file.writeAsString(updated);
    stdout.writeln('Added export of ref_endpoints.dart to ${file.path}.');
    return;
  }
}
