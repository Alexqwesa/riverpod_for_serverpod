import 'package:riverpod_for_serverpod_generator/src/build_provider_variant.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('buildRecordValueArgs', () {
    test('empty parameters should return empty parentheses', () {
      expect(
          buildRecordValueArgs(positional: [], namedPairs: []), equals('()'));
    });

    test('single positional parameter should return with parentheses', () {
      expect(buildRecordValueArgs(positional: ['arg1'], namedPairs: []),
          equals('(arg1)'));
    });

    test('multiple positional parameters should return with parentheses', () {
      expect(
        buildRecordValueArgs(positional: ['arg1', 'arg2'], namedPairs: []),
        equals('(arg1, arg2)'),
      );
    });

    test('single named parameter should return with record syntax', () {
      expect(
        buildRecordValueArgs(
            positional: [], namedPairs: [('filterFrom', 'filterFrom')]),
        equals('(filterFrom: filterFrom)'),
      );
    });

    test('multiple named parameters should return with record syntax', () {
      expect(
        buildRecordValueArgs(
          positional: [],
          namedPairs: [
            ('filterFrom', 'filterFrom'),
            ('filterTo', 'null'),
            ('filterStates', 'null'),
          ],
        ),
        equals('(filterFrom: filterFrom, filterTo: null, filterStates: null)'),
      );
    });

    test('mixed positional and named parameters should return combined', () {
      expect(
        buildRecordValueArgs(
          positional: ['arg1', 'arg2'],
          namedPairs: [('filterFrom', 'filterFrom'), ('filterTo', 'null')],
        ),
        equals('(arg1, arg2, filterFrom: filterFrom, filterTo: null)'),
      );
    });

    test('single positional with single named should return combined', () {
      expect(
        buildRecordValueArgs(
            positional: ['arg1'], namedPairs: [('filterFrom', 'filterFrom')]),
        equals('(arg1, filterFrom: filterFrom)'),
      );
    });
  });

  group('buildCallArgs', () {
    test('empty all parameters should return empty string', () {
      expect(
        buildCallArgs(
          positionalParams: [],
          requiredNamedParams: [],
          defaultableParams: [],
          takeCount: null,
        ),
        equals(''),
      );
    });

    test('single positional parameter should return just the name', () {
      final positional = [MyParamMeta('arg1', 'String', null)];
      expect(
        buildCallArgs(
          positionalParams: positional,
          requiredNamedParams: [],
          defaultableParams: [],
          takeCount: null,
        ),
        equals('arg1'),
      );
    });

    test('single required named parameter returns just the value', () {
      // When only 1 named arg, it returns just the value (not named syntax)
      final named = [MyParamMeta('filterFrom', 'DateTime?', null)];
      expect(
        buildCallArgs(
          positionalParams: [],
          requiredNamedParams: named,
          defaultableParams: [],
          takeCount: null,
        ),
        equals('filterFrom'),
      );
    });

    test('multiple required named parameters should return record syntax', () {
      final named = [
        MyParamMeta('filterFrom', 'DateTime?', null),
        MyParamMeta('filterTo', 'DateTime?', null),
      ];
      expect(
        buildCallArgs(
          positionalParams: [],
          requiredNamedParams: named,
          defaultableParams: [],
          takeCount: null,
        ),
        equals('(filterFrom: filterFrom, filterTo: filterTo)'),
      );
    });

    test('defaultable parameters with takeCount includes all defaultables', () {
      // buildCallArgs includes ALL defaultables even when takeCount is set
      final defaultable = [
        MyParamMeta('filterFrom', 'DateTime?', 'null'),
        MyParamMeta('filterTo', 'DateTime?', 'null'),
        MyParamMeta('filterStates', 'List<String>?', 'null'),
      ];
      expect(
        buildCallArgs(
          positionalParams: [],
          requiredNamedParams: [],
          defaultableParams: defaultable,
          takeCount: 1,
        ),
        equals('(filterFrom: filterFrom, filterTo: null, filterStates: null)'),
      );
    });

    test(
        'defaultable parameters without takeCount should include all with defaults',
        () {
      final defaultable = [
        MyParamMeta('filterFrom', 'DateTime?', 'DateTime.now()'),
        MyParamMeta('filterTo', 'DateTime?', 'null'),
      ];
      expect(
        buildCallArgs(
          positionalParams: [],
          requiredNamedParams: [],
          defaultableParams: defaultable,
          takeCount: null,
        ),
        equals('(filterFrom: DateTime.now(), filterTo: null)'),
      );
    });

    test('mixed positional and named parameters should combine correctly', () {
      final positional = [MyParamMeta('userId', 'int', null)];
      final requiredNamed = [MyParamMeta('filterFrom', 'DateTime?', null)];
      final defaultable = [
        MyParamMeta('filterTo', 'DateTime?', 'null'),
        MyParamMeta('filterStates', 'List<String>?', 'null'),
      ];
      // All defaultables are included, not just the first one
      expect(
        buildCallArgs(
          positionalParams: positional,
          requiredNamedParams: requiredNamed,
          defaultableParams: defaultable,
          takeCount: 1,
        ),
        equals(
            '(userId, filterFrom: filterFrom, filterTo: filterTo, filterStates: null)'),
      );
    });

    test('complex real-world scenario', () {
      final positional = [MyParamMeta('ref', 'Session', null)];
      final requiredNamed = [MyParamMeta('filterFrom', 'DateTime?', null)];
      final defaultable = [
        MyParamMeta('filterTo', 'DateTime?', 'null'),
        MyParamMeta('filterStates', 'List<String>?', 'null'),
        MyParamMeta('filterTypes', 'List<String>?', 'null'),
      ];
      expect(
        buildCallArgs(
          positionalParams: positional,
          requiredNamedParams: requiredNamed,
          defaultableParams: defaultable,
          takeCount: 3,
        ),
        equals(
            '(ref, filterFrom: filterFrom, filterTo: filterTo, filterStates: filterStates, filterTypes: filterTypes)'),
      );
    });
  });

  group('buildProviderVariants', () {
    MyMethodMeta makeMethod({
      required String name,
      required String returnType,
      List<MyParamMeta> positionalParams = const [],
      List<MyParamMeta> namedParams = const [],
    }) {
      return MyMethodMeta(
        name,
        returnType,
        positionalParams,
        namedParams,
        positionalParams.isNotEmpty,
        namedParams.isNotEmpty,
      );
    }

    test('no params yields no variants', () {
      final m = makeMethod(name: 'getAll', returnType: 'Future<List<User>>');
      final variants = buildProviderVariants(
        m,
        'List<User>',
        '',
        'user',
        'RefUserEndpoint',
      ).toList();
      expect(variants, isEmpty);
    });

    test('single positional param yields base variant with suffix 0', () {
      final m = makeMethod(
        name: 'getById',
        returnType: 'Future<User?>',
        positionalParams: [MyParamMeta('id', 'int', null)],
      );
      final variants = buildProviderVariants(
        m,
        'User?',
        '',
        'user',
        'RefUserEndpoint',
      ).toList();
      expect(variants.length, greaterThan(0));
      expect(variants.first.name, equals('getById0'));
      expect(
        variants.first.assignment.toString(),
        contains('retry: _noProviderRetry'),
      );
    });

    test('named params with defaults yields multiple variants', () {
      final m = makeMethod(
        name: 'search',
        returnType: 'Future<List<Item>>',
        namedParams: [
          MyParamMeta('filterFrom', 'DateTime?', 'null'),
          MyParamMeta('filterTo', 'DateTime?', 'null'),
        ],
      );
      final variants = buildProviderVariants(
        m,
        'List<Item>',
        '',
        'items',
        'RefItemEndpoint',
      ).toList();
      expect(variants.length, equals(3));
      expect(variants[0].name, equals('search0'));
      expect(variants[1].name, equals('search1'));
      expect(variants[2].name, equals('search2'));
    });

    test('named params without defaults but nullable yields multiple variants',
        () {
      // Nullable params are isDefaultable, so they generate additional variants
      final m = makeMethod(
        name: 'search',
        returnType: 'Future<List<Item>>',
        namedParams: [
          MyParamMeta(
              'filterFrom', 'DateTime?', null), // nullable = defaultable
          MyParamMeta('filterTo', 'DateTime?', null), // nullable = defaultable
        ],
      );
      final variants = buildProviderVariants(
        m,
        'List<Item>',
        '',
        'items',
        'RefItemEndpoint',
      ).toList();
      // Base variant 0 + 2 additional (one per defaultable param) = 3
      expect(variants.length, equals(3));
      expect(variants.first.name, equals('search0'));
    });
  });
}
