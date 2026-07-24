import 'dart:io';

import 'package:path/path.dart' as p;

/// Derives the sibling `*_client` package name from a Serverpod `*_server` package.
String deriveClientPackageName(String serverPackageName) {
  return _deriveSiblingPackageName(serverPackageName, 'client');
}

/// Derives the sibling `*_flutter` package name from a Serverpod `*_server` package.
String deriveFlutterPackageName(String serverPackageName) {
  return _deriveSiblingPackageName(serverPackageName, 'flutter');
}

String _deriveSiblingPackageName(String serverPackageName, String suffix) {
  if (serverPackageName.endsWith('_server')) {
    return '${serverPackageName.substring(0, serverPackageName.length - 7)}_$suffix';
  }
  return '${serverPackageName}_$suffix';
}

/// Sibling package directory next to [serverDir], or `null` if missing.
Directory? siblingPackageDir(Directory serverDir, String packageName) {
  final dir = Directory(p.join(serverDir.parent.path, packageName));
  if (!dir.existsSync()) return null;
  final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return null;
  return dir;
}

/// Reads `pubspec.yaml` from a sibling package directory, if present.
Future<String?> readSiblingPubspecYaml(
  Directory serverDir,
  String packageName,
) async {
  final dir = siblingPackageDir(serverDir, packageName);
  if (dir == null) return null;
  return File(p.join(dir.path, 'pubspec.yaml')).readAsString();
}
