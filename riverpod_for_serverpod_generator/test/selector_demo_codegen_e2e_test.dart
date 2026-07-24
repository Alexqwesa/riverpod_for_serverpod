import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// End-to-end contract checks against the committed selector_demo codegen
/// output (server generated file + client copy).
void main() {
  late final String serverText;
  late final String clientText;

  setUpAll(() {
    final root = _repoRoot();
    final serverFile = File(
      p.join(
        root,
        'example',
        'selector_demo',
        'selector_demo_server',
        'lib',
        'src',
        'generated',
        'ref_endpoints.dart',
      ),
    );
    final clientFile = File(
      p.join(
        root,
        'example',
        'selector_demo',
        'selector_demo_client',
        'lib',
        'ref_endpoints.dart',
      ),
    );

    expect(serverFile.existsSync(), isTrue, reason: serverFile.path);
    expect(clientFile.existsSync(), isTrue, reason: clientFile.path);

    serverText = serverFile.readAsStringSync();
    clientText = clientFile.readAsStringSync();
  });

  test('client ref_endpoints matches server generated output', () {
    expect(clientText, serverText);
  });

  test('CachedQuery.ttl drives cacheFor and putList for reads', () {
    expect(serverText, contains('ref.cacheFor(const Duration(minutes: 3))'));
    expect(serverText, contains('ttl: Duration(minutes: 3)'));
  });

  test('typed invalidate hooks use ProviderInvalidator for precise families', () {
    expect(
      serverText,
      contains(
        'static void listChildrenInvalidate(\n'
        '    ProviderInvalidator invalidate,\n'
        '    String args,\n'
        '  )',
      ),
    );
    expect(
      serverText,
      contains(
        'static void getSelectionInvalidate(\n'
        '    ProviderInvalidator invalidate,\n'
        '    String args,\n'
        '  )',
      ),
    );
  });

  test('saveSelection command + invalidateAfter use Reader/invalidate pair', () {
    expect(
      serverText,
      contains(
        'static Future<void> saveSelection(Reader read, ProviderInvalidator invalidate,',
      ),
    );
    expect(
      serverText,
      contains(
        'static void invalidateAfterSaveSelection(\n'
        '    Reader read,\n'
        '    ProviderInvalidator invalidate,\n'
        '    String parentId,\n'
        '  )',
      ),
    );
    expect(
      serverText,
      contains(
        'RefSelectorEndpoint.listChildrenInvalidate(invalidate, parentId);',
      ),
    );
    expect(
      serverText,
      contains(
        'RefSelectorEndpoint.getSelectionInvalidate(invalidate, parentId);',
      ),
    );
  });

  test('mutation controller and replay registration are emitted', () {
    expect(serverText, contains('selectorMutationControllerProvider'));
    expect(
      serverText,
      contains(
        "MutationRetryReplayRegistry.register(r'SelectorEndpoint.saveSelection'",
      ),
    );
    expect(
      serverText,
      contains(
        'await RefSelectorEndpointCommands.saveSelection(ref.read, ref.invalidate,',
      ),
    );
  });
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
