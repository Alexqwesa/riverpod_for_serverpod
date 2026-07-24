import 'package:riverpod_for_serverpod_generator/src/cached_query_codegen.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('parseCachedQueryReturnType', () {
    test('parses List element', () {
      final s = parseCachedQueryReturnType('List<Role>')!;
      expect(s.elementType, 'Role');
      expect(s.isList, isTrue);
      expect(s.valueNullable, isFalse);
    });

    test('parses nullable single value', () {
      final s = parseCachedQueryReturnType('Role?')!;
      expect(s.elementType, 'Role');
      expect(s.isList, isFalse);
      expect(s.valueNullable, isTrue);
    });

    test('parses non-null single value', () {
      final s = parseCachedQueryReturnType('Role')!;
      expect(s.elementType, 'Role');
      expect(s.isList, isFalse);
      expect(s.valueNullable, isFalse);
    });

    test('returns null for void', () {
      expect(parseCachedQueryReturnType('void'), isNull);
    });
  });

  group('cachedQueryIndexKeyExpression', () {
    test('no params uses static key', () {
      final m = MyMethodMeta(
        'listRoles',
        'Future<List<Role>>',
        [],
        [],
        false,
        false,
        innerProviderName: 'RefAdminEndpoint',
      );
      expect(
        cachedQueryIndexKeyExpression(m),
        "r'RefAdminEndpoint.listRoles'",
      );
    });

    test('uses jsonEncode for DateTime?', () {
      final m = MyMethodMeta(
        'byRange',
        'Future<List<Item>>',
        [],
        [MyParamMeta('from', 'DateTime?', null)],
        false,
        true,
        innerProviderName: 'RefIssueEndpoint',
      );
      expect(
        cachedQueryIndexKeyExpression(m),
        "r'RefIssueEndpoint.byRange' + ':' + jsonEncode([from?.toIso8601String()])",
      );
    });
  });

  group('keepAliveTtlExpression', () {
    test('uses CachedQuery.ttl when present', () {
      final m = MyMethodMeta(
        'listRoles',
        'Future<List<Role>>',
        [],
        [],
        false,
        false,
        cacheTtl: 'Duration(minutes: 3)',
        innerProviderName: 'RefAdminEndpoint',
        cachedQuery: const CachedQueryMeta(
          entity: 'Role',
          ttl: 'Duration(minutes: 10)',
        ),
      );
      expect(keepAliveTtlExpression(m), 'Duration(minutes: 10)');
    });

    test('falls back to CacheTtl / cacheTtl without CachedQuery', () {
      final m = MyMethodMeta(
        'listRoles',
        'Future<List<Role>>',
        [],
        [],
        false,
        false,
        cacheTtl: 'Duration(hours: 1)',
        innerProviderName: 'RefAdminEndpoint',
      );
      expect(keepAliveTtlExpression(m), 'Duration(hours: 1)');
    });
  });
}
