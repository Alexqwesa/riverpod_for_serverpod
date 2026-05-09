import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

/// Whether generated providers should pass [retry: _noProviderRetry] (Riverpod 3+).
///
/// Inspects [dependencies], [dev_dependencies], and [dependency_overrides] for
/// `riverpod` and `flutter_riverpod`. If no version constraint is found (path/git/sdk),
/// defaults to `true`. If **no** listed constraint allows `3.0.0`, returns `false`.
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
