import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:selector_demo_client/selector_demo_client.dart';
import 'package:selector_demo_flutter/main.dart' as app;

/// Integration e2e against a live Mini server.
///
/// Starts `../selector_demo_server` when nothing is already listening on
/// `http://127.0.0.1:8080/`. Run from `selector_demo_flutter`:
///
/// ```bash
/// flutter test integration_test/selector_demo_flow_e2e_test.dart -d windows
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Process? spawnedServer;
  var serverReady = false;

  setUpAll(() async {
    serverReady = await _waitForSelectorApi(timeout: const Duration(seconds: 2));
    if (serverReady) return;

    final serverDir = Directory(
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}selector_demo_server',
    );
    if (!File(
      '${serverDir.path}${Platform.pathSeparator}bin${Platform.pathSeparator}main.dart',
    ).existsSync()) {
      return;
    }

    spawnedServer = await Process.start(
      'dart',
      ['run', 'bin/main.dart'],
      workingDirectory: serverDir.path,
      runInShell: true,
    );
    unawaited(spawnedServer!.stdout.drain());
    unawaited(spawnedServer!.stderr.drain());
    serverReady = await _waitForSelectorApi(
      timeout: const Duration(seconds: 45),
    );
  });

  tearDownAll(() async {
    final proc = spawnedServer;
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

  testWidgets('department load + child save round-trip', (tester) async {
    expect(serverReady, isTrue, reason: 'Mini server must be reachable');

    await app.bootstrap();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byKey(const Key('app_title')), findsOneWidget);
    expect(find.byKey(const Key('selector_scaffold')), findsOneWidget);
    expect(find.byKey(const Key('parents_error')), findsNothing);
    expect(find.byKey(const Key('parent_picker')), findsOneWidget);

    await tester.tap(find.text('Choose a department'));
    await tester.pumpAndSettle();
    expect(find.text('Electronics'), findsOneWidget);
    expect(find.text('Grocery'), findsOneWidget);

    await tester.tap(find.text('Grocery'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.textContaining('Department: Grocery'), findsOneWidget);
    expect(find.byKey(const Key('child_picker')), findsOneWidget);

    await tester.tap(
      find.text('Choose items (multi-select), then close to save'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();

    final close = find.byIcon(Icons.arrow_back);
    expect(close, findsWidgets);
    await tester.tap(close.first);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.textContaining('Selection saved on server'), findsOneWidget);
    expect(find.byKey(const Key('saved_summary')), findsOneWidget);
    expect(find.textContaining('c-apple'), findsOneWidget);
  });
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
      // Not ready yet.
    } finally {
      client.close();
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  return false;
}
