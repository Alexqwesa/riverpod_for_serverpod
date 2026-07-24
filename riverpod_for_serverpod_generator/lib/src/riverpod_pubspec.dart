import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:riverpod_for_serverpod_generator/src/serverpod_packages.dart';
import 'package:yaml/yaml.dart';

/// Whether generated output should use Riverpod 3-only APIs ([retry] on functional
/// providers, [Ref.mounted] in [Ref.cacheFor]).
///
/// When any `riverpod` / `flutter_riverpod` constraint **allows** version `3.0.0`, this
/// is `true`. When all listed constraints exclude 3.x, this is `false` (Riverpod 2
/// workarounds: omit `retry`, use try/catch in `cacheFor` instead of `mounted`).
bool inferEmitProviderRetry(String pubspecYaml) {
  final constraints = collectRiverpodConstraints(pubspecYaml);
  if (constraints.isEmpty) return true;

  final v3 = Version(3, 0, 0);
  for (final cstr in constraints) {
    try {
      if (VersionConstraint.parse(cstr).allows(v3)) return true;
    } on FormatException {
      // Unrecognized constraint → assume modern Riverpod.
      return true;
    }
  }
  return false;
}

/// Collects `riverpod` / `flutter_riverpod` constraint strings from a pubspec.
List<String> collectRiverpodConstraints(String pubspecYaml) {
  final doc = loadYaml(pubspecYaml);
  if (doc is! YamlMap) return const [];

  final constraints = <String>[];
  void collect(YamlMap? section) {
    if (section == null) return;
    for (final name in ['riverpod', 'flutter_riverpod']) {
      final raw = section[name];
      final s = constraintStringFromDepValue(raw);
      if (s != null) constraints.add(s);
    }
  }

  collect(doc['dependencies'] as YamlMap?);
  collect(doc['dev_dependencies'] as YamlMap?);
  collect(doc['dependency_overrides'] as YamlMap?);
  return constraints;
}

bool hasRiverpodConstraint(String pubspecYaml) =>
    collectRiverpodConstraints(pubspecYaml).isNotEmpty;

String? constraintStringFromDepValue(Object? value) {
  if (value is String) return value;
  if (value is YamlMap) {
    final v = value['version'];
    if (v is String) return v;
  }
  return null;
}

/// Preferred Riverpod constraint for the client, taken from Flutter/client pubspecs.
///
/// Prefers `flutter_riverpod` / `riverpod` from the Flutter package, then the client.
String? preferredRiverpodConstraint({
  String? flutterPubspecYaml,
  String? clientPubspecYaml,
}) {
  for (final yaml in [flutterPubspecYaml, clientPubspecYaml]) {
    if (yaml == null) continue;
    final doc = loadYaml(yaml);
    if (doc is! YamlMap) continue;
    for (final sectionName in [
      'dependencies',
      'dev_dependencies',
      'dependency_overrides',
    ]) {
      final section = doc[sectionName];
      if (section is! YamlMap) continue;
      for (final name in ['flutter_riverpod', 'riverpod']) {
        final c = constraintStringFromDepValue(section[name]);
        if (c != null) return c;
      }
    }
  }
  return null;
}

/// Resolves Riverpod 3 codegen mode from sibling Serverpod packages.
///
/// Lookup order (first pubspec that declares `riverpod` / `flutter_riverpod` wins):
/// 1. `*_flutter`
/// 2. `*_client`
/// 3. server [serverPubspecYaml]
///
/// When none declare a constraint, defaults to Riverpod 3 (`true`).
Future<bool> resolveEmitProviderRetry({
  required Directory serverDir,
  required String serverPackageName,
  required String serverPubspecYaml,
}) async {
  final flutterYaml = await readSiblingPubspecYaml(
    serverDir,
    deriveFlutterPackageName(serverPackageName),
  );
  if (flutterYaml != null && hasRiverpodConstraint(flutterYaml)) {
    return inferEmitProviderRetry(flutterYaml);
  }

  final clientYaml = await readSiblingPubspecYaml(
    serverDir,
    deriveClientPackageName(serverPackageName),
  );
  if (clientYaml != null && hasRiverpodConstraint(clientYaml)) {
    return inferEmitProviderRetry(clientYaml);
  }

  return inferEmitProviderRetry(serverPubspecYaml);
}

/// Package directory used while `build_runner` / scripts run in the server package.
Directory resolveServerPackageDir() {
  final cwd = Directory.current;
  final pubspec = File(p.join(cwd.path, 'pubspec.yaml'));
  if (pubspec.existsSync()) return cwd;
  return cwd;
}
