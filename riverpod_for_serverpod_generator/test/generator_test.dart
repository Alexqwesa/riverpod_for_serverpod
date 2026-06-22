import 'package:riverpod_for_serverpod_generator/src/generator.dart';
import 'package:test/test.dart';

void main() {
  group('deriveClientPackageName', () {
    test('maps *_server to *_client', () {
      expect(
        deriveClientPackageName('banks_aggregator_server'),
        'banks_aggregator_client',
      );
      expect(
        deriveClientPackageName('vsp_dsno_server'),
        'vsp_dsno_client',
      );
    });

    test('falls back to appending _client', () {
      expect(deriveClientPackageName('demo'), 'demo_client');
    });
  });

  group('normalizeHookTargets', () {
    test('prefixes Ref and deduplicates endpoint names', () {
      expect(
        normalizeHookTargets([
          'AdminEndpoint',
          'RefAdminEndpoint',
          'UserSummaryEndpoint',
          '',
        ]),
        ['RefAdminEndpoint', 'RefUserSummaryEndpoint'],
      );
    });
  });

  group('collectRequiredDartImports', () {
    test('adds dart:typed_data when ByteData is used', () {
      expect(
        collectRequiredDartImports('FutureProvider<ByteData?> getFileBytes;'),
        ['dart:typed_data'],
      );
    });

    test('adds dart:convert when json helpers are used', () {
      expect(
        collectRequiredDartImports('final value = jsonDecode(raw);'),
        ['dart:convert'],
      );
    });

    test('adds both imports when both feature sets are used', () {
      expect(
        collectRequiredDartImports(
            'Uint8List bytes; final value = utf8.decode(raw);'),
        ['dart:convert', 'dart:typed_data'],
      );
    });

    test('returns no extra imports when no special types are used', () {
      expect(
        collectRequiredDartImports('FutureProvider<String> hello;'),
        isEmpty,
      );
    });
  });

  group('buildGeneratedImportLines', () {
    test('Riverpod 3 imports ProviderListenable from misc', () {
      expect(
        buildGeneratedImportLines(
          importPaths: const ['package:riverpod/riverpod.dart'],
          emitProviderRetry: true,
        ),
        contains(
          "import 'package:riverpod/misc.dart' show ProviderListenable;",
        ),
      );
    });

    test('Riverpod 2 does not import ProviderListenable from misc', () {
      expect(
        buildGeneratedImportLines(
          importPaths: const ['package:riverpod/riverpod.dart'],
          emitProviderRetry: false,
        ),
        isNot(
          contains(
            "import 'package:riverpod/misc.dart' show ProviderListenable;",
          ),
        ),
      );
    });
  });

  group('emittedRefCacheForExtension', () {
    test('Riverpod 3 uses mounted guard', () {
      expect(
        emittedRefCacheForExtension(emitProviderRetry: true),
        contains('if (!mounted) return;'),
      );
      expect(
        emittedRefCacheForExtension(emitProviderRetry: true),
        isNot(contains('on StateError')),
      );
    });

    test('Riverpod 2 uses StateError workaround without mounted', () {
      final src = emittedRefCacheForExtension(emitProviderRetry: false);
      expect(src, contains('on StateError'));
      expect(src, isNot(contains('mounted')));
    });
  });
}
