import 'dart:async';
import 'dart:io';

import 'package:riverpod/riverpod.dart';
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:selector_demo_client/selector_demo_client.dart';
import 'package:test/test.dart';

/// Live Mini-server e2e through generated Riverpod providers.
///
/// Spawns `../selector_demo_server` when the selector API is not already
/// healthy on `:8080`. Run from `selector_demo_client`:
///
/// ```bash
/// dart test test/ref_endpoints_live_e2e_test.dart
/// ```
void main() {
  Process? server;
  var serverReady = false;
  var spawnedBySuite = false;

  setUpAll(() async {
    final serverDir = _resolveServerDir();
    expect(serverDir.existsSync(), isTrue, reason: serverDir.path);

    serverReady = await _waitForSelectorApi(
      timeout: const Duration(seconds: 2),
    );
    if (!serverReady) {
      server = await Process.start(
        'dart',
        ['run', 'bin/main.dart'],
        workingDirectory: serverDir.path,
        mode: ProcessStartMode.normal,
        runInShell: true,
      );
      spawnedBySuite = true;
      unawaited(stdout.addStream(server!.stdout));
      unawaited(stderr.addStream(server!.stderr));

      serverReady = await _waitForSelectorApi(
        timeout: const Duration(seconds: 45),
      );
    }
  });

  tearDownAll(() async {
    if (!spawnedBySuite) return;
    final proc = server;
    if (proc == null) return;
    proc.kill(ProcessSignal.sigterm);
    await proc.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        proc.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  });

  ProviderContainer newContainer() {
    return ProviderContainer(
      overrides: [
        clientProvider.overrideWithValue(Client('http://127.0.0.1:8080/')),
        generatedCacheStorageProvider.overrideWith(
          (ref) async => MemoryGeneratedCacheStorage(),
        ),
      ],
    );
  }

  test(
    'listParents via generated provider',
    () async {
      expect(
        serverReady,
        isTrue,
        reason: 'Mini server did not become ready at http://127.0.0.1:8080/',
      );
      final container = newContainer();
      addTearDown(container.dispose);
      final sub = container.listen(RefSelectorEndpoint.listParents, (_, __) {});
      addTearDown(sub.close);

      final parents =
          await container.read(RefSelectorEndpoint.listParents.future);
      expect(parents.map((p) => p.id), contains('dept-electronics'));
      expect(parents.length, greaterThanOrEqualTo(2));
    },
    tags: ['live-server', 'e2e'],
  );

  test(
    'saveSelection then getSelection via generated command',
    () async {
      expect(
        serverReady,
        isTrue,
        reason: 'Mini server did not become ready at http://127.0.0.1:8080/',
      );
      final container = newContainer();
      addTearDown(container.dispose);

      const parentId = 'dept-electronics';
      final ids = <String>['c-laptop', 'c-phone'];
      final selectionProvider = RefSelectorEndpoint.getSelection(parentId);
      final sub = container.listen(selectionProvider, (_, __) {});
      addTearDown(sub.close);

      await container
          .read(selectorMutationControllerProvider.notifier)
          .saveSelection(parentId, ids);

      final mutation = container.read(selectorMutationControllerProvider);
      expect(mutation.hasError, isFalse, reason: '${mutation.error}');

      container.invalidate(selectionProvider);
      final snap = await container.read(selectionProvider.future);
      expect(snap.selectedChildIds, containsAll(ids));
    },
    tags: ['live-server', 'e2e'],
  );

  test(
    'listChildren returns seeded items for parent',
    () async {
      expect(
        serverReady,
        isTrue,
        reason: 'Mini server did not become ready at http://127.0.0.1:8080/',
      );
      final container = newContainer();
      addTearDown(container.dispose);
      final childrenProvider =
          RefSelectorEndpoint.listChildren('dept-electronics');
      final sub = container.listen(childrenProvider, (_, __) {});
      addTearDown(sub.close);

      final children = await container.read(childrenProvider.future);
      expect(children.map((c) => c.id), containsAll(['c-laptop', 'c-phone']));
    },
    tags: ['live-server', 'e2e'],
  );
}

Directory _resolveServerDir() {
  bool isServer(Directory d) => File(
        '${d.path}${Platform.pathSeparator}bin${Platform.pathSeparator}main.dart',
      ).existsSync();

  final sibling = Directory(
    '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}selector_demo_server',
  );
  if (sibling.existsSync() && isServer(sibling)) return sibling;

  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final candidate = Directory(
      '${dir.path}${Platform.pathSeparator}example${Platform.pathSeparator}selector_demo${Platform.pathSeparator}selector_demo_server',
    );
    if (candidate.existsSync() && isServer(candidate)) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Could not locate selector_demo_server from ${Directory.current.path}');
}

Future<bool> _waitForSelectorApi({required Duration timeout}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final client = Client('http://127.0.0.1:8080/');
    try {
      final parents = await client.selector
          .listParents()
          .timeout(const Duration(seconds: 2));
      if (parents.isNotEmpty) return true;
    } catch (_) {
      // Not ready yet (or wrong process on :8080).
    } finally {
      client.close();
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  return false;
}
