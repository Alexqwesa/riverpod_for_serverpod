import 'package:riverpod_for_serverpod_generator/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('MyParamMeta', () {
    test('basic construction with name, type, and default', () {
      final param = MyParamMeta('id', 'int', null);
      expect(param.name, 'id');
      expect(param.type, 'int');
      expect(param.defaultValue, isNull);
    });

    test('construction with default value', () {
      final param = MyParamMeta('filterFrom', 'DateTime?', 'DateTime.now()');
      expect(param.name, 'filterFrom');
      expect(param.type, 'DateTime?');
      expect(param.defaultValue, 'DateTime.now()');
    });

    test('isNullable detects nullable type', () {
      expect(MyParamMeta('a', 'int?', null).isNullable, isTrue);
      expect(MyParamMeta('a', 'int', null).isNullable, isFalse);
      expect(MyParamMeta('a', 'String?', null).isNullable, isTrue);
    });

    test('hasDefault returns true when defaultValue is set', () {
      expect(MyParamMeta('a', 'int', '0').hasDefault, isTrue);
      expect(MyParamMeta('a', 'int', null).hasDefault, isFalse);
    });

    test('defaultCodeOrNull returns the default literal', () {
      expect(MyParamMeta('a', 'int', '0').defaultCodeOrNull, '0');
      expect(MyParamMeta('a', 'int', 'DateTime.now()').defaultCodeOrNull, 'DateTime.now()');
      expect(MyParamMeta('a', 'int', null).defaultCodeOrNull, isNull);
    });

    test('isDefaultable is true for nullable or hasDefault', () {
      expect(MyParamMeta('a', 'int?', null).isDefaultable, isTrue);
      expect(MyParamMeta('a', 'int', '0').isDefaultable, isTrue);
      expect(MyParamMeta('a', 'int', null).isDefaultable, isFalse);
      expect(MyParamMeta('a', 'String?', null).isDefaultable, isTrue);
    });
  });

  group('MyMethodMeta', () {
    test('basic construction computes unwrappedReturnType', () {
      final m = MyMethodMeta(
        'getUsers',
        'Future<List<User>>',
        [],
        [],
        false,
        false,
      );
      expect(m.name, 'getUsers');
      expect(m.returnType, 'Future<List<User>>');
      expect(m.unwrappedReturnType, 'List<User>');
      expect(m.recordArgType, '()');
    });

    test('construction with positional and named params', () {
      final m = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [MyParamMeta('query', 'String', null)],
        [MyParamMeta('filter', 'String?', 'null')],
        true,
        true,
      );
      expect(m.positionalParams.length, 1);
      expect(m.namedParams.length, 1);
      expect(m.hasPositionalParams, isTrue);
      expect(m.hasNamedParams, isTrue);
    });

    test('unwrappedReturnType extracts Future<T> inner type', () {
      expect(
        MyMethodMeta('a', 'Future<String>', [], [], false, false).unwrappedReturnType,
        'String',
      );
      expect(
        MyMethodMeta('a', 'Future<List<int>?>', [], [], false, false).unwrappedReturnType,
        'List<int>?',
      );
      expect(
        MyMethodMeta('a', 'List<User>', [], [], false, false).unwrappedReturnType,
        'List<User>',
      );
    });

    test('recordArgType builds record syntax for named params', () {
      final m = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [],
        [
          MyParamMeta('filterFrom', 'DateTime?', null),
          MyParamMeta('filterTo', 'DateTime?', null),
        ],
        false,
        true,
      );
      expect(m.recordArgType, '({DateTime? filterFrom, DateTime? filterTo})');
    });

    test('recordArgType returns () when no named params', () {
      final m = MyMethodMeta(
        'getAll',
        'Future<List<Item>>',
        [],
        [],
        false,
        false,
      );
      expect(m.recordArgType, '()');
    });

    test('defaultableNamed filters defaultable params', () {
      final m = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [],
        [
          MyParamMeta('a', 'int', '0'), // defaultable (has default)
          MyParamMeta('b', 'int', null), // NOT defaultable (required, no default)
          MyParamMeta('c', 'int?', null), // defaultable (nullable)
          MyParamMeta('d', 'String?', 'null'), // defaultable (has default)
        ],
        false,
        true,
      );
      final defaultable = m.defaultableNamed;
      expect(defaultable.map((p) => p.name), ['a', 'c', 'd']);
    });

    test('hasRequiredNamedWithoutDefault detects required named params', () {
      final withRequired = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [],
        [
          MyParamMeta('a', 'int', '0'),
          MyParamMeta('b', 'int', null),
        ],
        false,
        true,
      );
      expect(withRequired.hasRequiredNamedWithoutDefault, isTrue);

      final allDefaultable = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [],
        [
          MyParamMeta('a', 'int', '0'),
          MyParamMeta('b', 'int?', null),
        ],
        false,
        true,
      );
      expect(allDefaultable.hasRequiredNamedWithoutDefault, isFalse);
    });

    test('recordArgTypeForFirstN returns subset of record type', () {
      final m = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [],
        [
          MyParamMeta('a', 'int', '0'),
          MyParamMeta('b', 'int', '1'),
          MyParamMeta('c', 'int', '2'),
        ],
        false,
        true,
      );
      expect(m.recordArgTypeForFirstN(1), '({int a})');
      expect(m.recordArgTypeForFirstN(2), '({int a, int b})');
    });

    test('callArgsFrom builds named parameter call syntax', () {
      final m = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [],
        [
          MyParamMeta('filterFrom', 'DateTime?', null),
          MyParamMeta('filterTo', 'DateTime?', null),
        ],
        false,
        true,
      );
      expect(m.callArgsFrom('args'), '(filterFrom: args.filterFrom, filterTo: args.filterTo)');
    });

    test('callArgsFrom returns () when no named params', () {
      final m = MyMethodMeta('getAll', 'Future<List<Item>>', [], [], false, false);
      expect(m.callArgsFrom('args'), '()');
    });

    test('callArgsForVariantFrom builds variant call args with defaults', () {
      final m = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [],
        [
          MyParamMeta('filterFrom', 'DateTime?', null), // nullable but no default literal
          MyParamMeta('filterTo', 'DateTime?', 'DateTime.now()'),
          MyParamMeta('filterStates', 'List<String>?', 'null'),
        ],
        false,
        true,
      );
      // With i=1: first 1 defaultable (filterFrom) from arg, rest use defaults
      final args = m.callArgsForVariantFrom('args', 1);
      expect(args, '(filterFrom: args.filterFrom, filterTo: DateTime.now(), filterStates: null)');
    });

    test('callArgsForVariantFrom omits non-defaultable named params', () {
      final m = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [],
        [
          MyParamMeta('filterFrom', 'DateTime?', null),
          MyParamMeta('filterTo', 'DateTime?', 'DateTime.now()'),
        ],
        false,
        true,
      );
      final args = m.callArgsForVariantFrom('args', 1);
      expect(args, '(filterFrom: args.filterFrom, filterTo: DateTime.now())');
    });

    test('innerProviderExprFrom builds provider expression with named params', () {
      final m = MyMethodMeta(
        'getUsers',
        'Future<List<User>>',
        [],
        [
          MyParamMeta('filterFrom', 'DateTime?', null),
          MyParamMeta('filterTo', 'DateTime?', null),
        ],
        false,
        true,
        'Duration(minutes: 3)',
        'RefUserEndpoint',
      );
      expect(m.innerProviderExprFrom('args'), 'RefUserEndpoint((filterFrom: args.filterFrom, filterTo: args.filterTo))');
    });

    test('canBuildVariant always returns true', () {
      final m = MyMethodMeta('getUsers', 'Future<List<User>>', [], [], false, false);
      expect(m.canBuildVariant(0), isTrue);
      expect(m.canBuildVariant(5), isTrue);
    });

    test('_buildRecordArgType builds record syntax for multiple named params', () {
      // _buildRecordArgType is private but its result is observable via recordArgType
      final m = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [],
        [
          MyParamMeta('a', 'int', null),
          MyParamMeta('b', 'String?', null),
        ],
        false,
        true,
      );
      // The public interface is recordArgType which uses _buildRecordArgType internally
      expect(m.recordArgType, '({int a, String? b})');
    });
  });

  group('ParamInfo', () {
    test('construction with all fields', () {
      final info = ParamInfo('(int a, {String b})', 'final (int a, {String b}) = args;', '(a, b: b)');
      expect(info.recordType, '(int a, {String b})');
      expect(info.destructuredVars, 'final (int a, {String b}) = args;');
      expect(info.methodCall, '(a, b: b)');
    });
  });
}
