import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

/// Whether generated output should use Riverpod 3-only APIs ([retry] on functional
/// providers, [Ref.mounted] in [Ref.cacheFor]).
///
/// When any `riverpod` / `flutter_riverpod` constraint **allows** version `3.0.0`, this
/// is `true`. When all listed constraints exclude 3.x, this is `false` (Riverpod 2
/// workarounds: omit `retry`, use try/catch in `cacheFor` instead of `mounted`).
bool inferEmitProviderRetry(String pubspecYaml) {
  final doc = loadYaml(pubspecYaml);
  if (doc is! YamlMap) return true;

  final constraints = <String>[];
  void collect(YamlMap? section) {
    if (section == null) return;
    for (final name in ['riverpod', 'flutter_riverpod']) {
      final raw = section[name];
      final s = _constraintStringFromDepValue(raw);
      if (s != null) constraints.add(s);
    }
  }

  collect(doc['dependencies'] as YamlMap?);
  collect(doc['dev_dependencies'] as YamlMap?);
  collect(doc['dependency_overrides'] as YamlMap?);

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

String? _constraintStringFromDepValue(Object? value) {
  if (value is String) return value;
  if (value is YamlMap) {
    final v = value['version'];
    if (v is String) return v;
  }
  return null;
}
