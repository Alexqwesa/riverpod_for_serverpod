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
        collectRequiredDartImports('Uint8List bytes; final value = utf8.decode(raw);'),
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
}
