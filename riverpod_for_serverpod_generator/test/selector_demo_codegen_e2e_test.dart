import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Generator e2e against the real selector_demo workspace.
///
/// 1. Runs `build_runner` in `selector_demo_server` (writes
///    `lib/src/generated/ref_endpoints.dart`).
/// 2. Runs `copy_ref_endpoints --no-ensure-deps` (writes
///    `selector_demo_client/lib/ref_endpoints.dart`).
/// 3. Asserts structural contracts on the regenerated output.
/// 4. Fails if regeneration leaves those files dirty vs git HEAD
///    (so each revision must commit an up-to-date generated pair).
///
/// After changing the generator:
///
/// ```bash
/// cd riverpod_for_serverpod_generator
/// dart test test/selector_demo_codegen_e2e_test.dart
/// git add ../example/selector_demo/selector_demo_server/lib/src/generated/ref_endpoints.dart \
///         ../example/selector_demo/selector_demo_client/lib/ref_endpoints.dart
/// git commit -m "Regenerate selector_demo ref_endpoints"
/// ```
///
/// Skip the slow build with `--exclude-tags generator-e2e`.
void main() {
  late final Directory repoRoot;
  late final Directory serverDir;
  late final File serverGenerated;
  late final File clientGenerated;

  setUpAll(() {
    repoRoot = Directory(_repoRoot());
    serverDir = Directory(
      p.join(repoRoot.path, 'example', 'selector_demo', 'selector_demo_server'),
    );
    serverGenerated = File(
      p.join(serverDir.path, 'lib', 'src', 'generated', 'ref_endpoints.dart'),
    );
    clientGenerated = File(
      p.join(
        repoRoot.path,
        'example',
        'selector_demo',
        'selector_demo_client',
        'lib',
        'ref_endpoints.dart',
      ),
    );

    expect(serverDir.existsSync(), isTrue, reason: serverDir.path);
  });

  test(
    'regenerates selector_demo ref_endpoints and matches git HEAD',
    () async {
      // Prove generation actually writes the files.
      if (serverGenerated.existsSync()) {
        await serverGenerated.delete();
      }
      if (clientGenerated.existsSync()) {
        await clientGenerated.delete();
      }

      final build = await Process.run(
        'dart',
        [
          'run',
          'build_runner',
          'build',
          '--delete-conflicting-outputs',
        ],
        workingDirectory: serverDir.path,
        runInShell: true,
      );
      expect(
        build.exitCode,
        0,
        reason: 'build_runner failed:\n'
            'stdout:\n${build.stdout}\n'
            'stderr:\n${build.stderr}',
      );

      expect(
        serverGenerated.existsSync(),
        isTrue,
        reason: 'Expected build_runner to write ${serverGenerated.path}',
      );

      final copy = await Process.run(
        'dart',
        [
          'run',
          'riverpod_for_serverpod_generator:copy_ref_endpoints',
          '--no-ensure-deps',
        ],
        workingDirectory: serverDir.path,
        runInShell: true,
      );
      expect(
        copy.exitCode,
        0,
        reason: 'copy_ref_endpoints failed:\n'
            'stdout:\n${copy.stdout}\n'
            'stderr:\n${copy.stderr}',
      );

      expect(
        clientGenerated.existsSync(),
        isTrue,
        reason: 'Expected copy to write ${clientGenerated.path}',
      );

      final serverText = await serverGenerated.readAsString();
      final clientText = await clientGenerated.readAsString();

      expect(clientText, serverText);
      _assertGeneratedContracts(serverText);

      // Per-revision gate: committed goldens must equal this regeneration.
      final drift = await Process.run(
        'git',
        [
          'diff',
          '--exit-code',
          '--',
          p.relative(serverGenerated.path, from: repoRoot.path),
          p.relative(clientGenerated.path, from: repoRoot.path),
        ],
        workingDirectory: repoRoot.path,
        runInShell: true,
      );
      if (drift.exitCode != 0) {
        fail(
          'Regenerated ref_endpoints.dart differs from git HEAD.\n'
          'Review the diff, then commit both files:\n'
          '  ${p.relative(serverGenerated.path, from: repoRoot.path)}\n'
          '  ${p.relative(clientGenerated.path, from: repoRoot.path)}\n\n'
          '${drift.stdout}\n${drift.stderr}',
        );
      }
    },
    tags: ['e2e', 'generator-e2e'],
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

void _assertGeneratedContracts(String text) {
  expect(text, isNotEmpty);
  expect(text, contains('ref.cacheFor(const Duration(minutes: 3))'));
  expect(text, contains('ttl: Duration(minutes: 3)'));
  expect(text, contains('listChildrenInvalidate'));
  expect(text, contains('getSelectionInvalidate'));
  expect(
    text,
    contains(
      'static Future<void> saveSelection(Reader read, ProviderInvalidator invalidate,',
    ),
  );
  expect(text, contains('invalidateAfterSaveSelection'));
  expect(
    text,
    contains('RefSelectorEndpoint.listChildrenInvalidate(invalidate, parentId);'),
  );
  expect(
    text,
    contains('RefSelectorEndpoint.getSelectionInvalidate(invalidate, parentId);'),
  );
  expect(text, contains('selectorMutationControllerProvider'));
  expect(
    text,
    contains(
      "MutationRetryReplayRegistry.register(r'SelectorEndpoint.saveSelection'",
    ),
  );
}

String _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final marker = Directory(
      p.join(dir.path, 'riverpod_for_serverpod_generator'),
    );
    final example = Directory(p.join(dir.path, 'example', 'selector_demo'));
    if (marker.existsSync() && example.existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail(
    'Could not locate repo root from ${Directory.current.path}. '
    'Run `dart test` from the monorepo or generator package.',
  );
}
