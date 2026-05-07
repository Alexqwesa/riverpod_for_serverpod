import 'package:code_builder/code_builder.dart';
import 'package:riverpod_for_serverpod_generator/src/build_provider_field.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('buildProviderField', () {
    MyMethodMeta makeMethod({
      required String name,
      required String returnType,
      List<MyParamMeta> positionalParams = const [],
      List<MyParamMeta> namedParams = const [],
      String cacheTtl = 'Duration(minutes: 3)',
      String? timeout,
    }) {
      return MyMethodMeta(
        name,
        returnType,
        positionalParams,
        namedParams,
        positionalParams.isNotEmpty,
        namedParams.isNotEmpty,
        cacheTtl,
        'RefTestEndpoint',
        timeout,
      );
    }

    test('zero params dispatches to buildZeroParamField', () {
      final m = makeMethod(name: 'getAll', returnType: 'Future<List<User>>');
      final field = buildProviderField(m, 'List<User>', '', 'user');
      expect(field.name, 'getAll');
      expect(field.static, isTrue);
    });

    test('single positional dispatches to buildSinglePositionalField', () {
      final m = makeMethod(
        name: 'getById',
        returnType: 'Future<User?>',
        positionalParams: [MyParamMeta('id', 'int', null)],
      );
      final field = buildProviderField(m, 'User?', '', 'user');
      expect(field.name, 'getById');
    });

    test('single named dispatches to buildSingleNamedField', () {
      final m = makeMethod(
        name: 'getByFilter',
        returnType: 'Future<List<Item>>',
        namedParams: [MyParamMeta('filter', 'String?', null)],
      );
      final field = buildProviderField(m, 'List<Item>', '', 'items');
      expect(field.name, 'getByFilter');
    });

    test('mixed params dispatches to buildMixedOrMultiParamField', () {
      final m = makeMethod(
        name: 'search',
        returnType: 'Future<List<Item>>',
        positionalParams: [MyParamMeta('query', 'String', null)],
        namedParams: [MyParamMeta('filter', 'String?', null)],
      );
      final field = buildProviderField(m, 'List<Item>', '', 'items');
      expect(field.name, 'search');
    });

    test('multiple named dispatches to buildMixedOrMultiParamField', () {
      final m = makeMethod(
        name: 'search',
        returnType: 'Future<List<Item>>',
        namedParams: [
          MyParamMeta('filterFrom', 'DateTime?', null),
          MyParamMeta('filterTo', 'DateTime?', null),
        ],
      );
      final field = buildProviderField(m, 'List<Item>', '', 'items');
      expect(field.name, 'search');
    });
  });

  group('buildZeroParamField', () {
    MyMethodMeta makeMethod({
      String name = 'getAll',
      String returnType = 'Future<List<User>>',
    }) {
      return MyMethodMeta(
        name,
        returnType,
        [],
        [],
        false,
        false,
        'Duration(minutes: 3)',
        'RefTestEndpoint',
      );
    }

    test('generates static AutoDisposeFutureProvider field', () {
      final m = makeMethod();
      final field = buildZeroParamField(m, 'List<User>', '', 'user');
      expect(field.static, isTrue);
      expect(field.modifier, equals(FieldModifier.final$));
    });

    test('field name matches method name', () {
      final m = makeMethod(name: 'listUsers');
      final field = buildZeroParamField(m, 'List<User>', '', 'user');
      expect(field.name, 'listUsers');
    });

    test('assignment uses AutoDisposeFutureProvider with correct type', () {
      final m = makeMethod();
      final field = buildZeroParamField(m, 'List<User>', '', 'user');
      final code = field.assignment.toString();
      expect(code, contains('FutureProvider.autoDispose<List<User>>'));
    });

    test('disables Riverpod 3 automatic retry', () {
      final m = makeMethod();
      final field = buildZeroParamField(m, 'List<User>', '', 'user');
      final code = field.assignment.toString();
      expect(code, contains('retry: _noProviderRetry'));
    });

    test('timeout suffix added when timeout is set', () {
      final m = MyMethodMeta(
        'getData',
        'Future<String>',
        [],
        [],
        false,
        false,
        'Duration(minutes: 3)',
        'RefTestEndpoint',
        'Duration(seconds: 30)',
      );
      final field = buildZeroParamField(m, 'String', '', 'client');
      final code = field.assignment.toString();
      expect(code, contains('.timeout('));
    });

    test('caches only after successful result', () {
      final m = makeMethod();
      final field = buildZeroParamField(m, 'List<User>', '', 'user');
      final code = field.assignment.toString();
      expect(code, contains('final result = await'));
      expect(code.indexOf('ref.cacheFor'), greaterThan(code.indexOf('await')));
      expect(
        code.indexOf('return result'),
        greaterThan(code.indexOf('ref.cacheFor')),
      );
    });

    test('void methods cache after awaited call', () {
      final m = makeMethod(name: 'refresh', returnType: 'Future<void>');
      final field = buildZeroParamField(m, 'void', '', 'user');
      final code = field.assignment.toString();
      expect(code, contains('await ref.watch(clientProvider).user.refresh();'));
      expect(code.indexOf('ref.cacheFor'), greaterThan(code.indexOf('await')));
      expect(code, isNot(contains('return result')));
    });
  });

  group('buildSinglePositionalField', () {
    test('generates AutoDisposeFutureProviderFamily field', () {
      final m = MyMethodMeta(
        'getById',
        'Future<User?>',
        [MyParamMeta('id', 'int', null)],
        [],
        true,
        false,
      );
      final field = buildSinglePositionalField(m, 'User?', '', 'user');
      expect(field.static, isTrue);
      final code = field.assignment.toString();
      expect(code, contains('FutureProvider.autoDispose'));
      expect(code, contains('.family<User?, int>'));
    });

    test('param type is correctly reflected in family assignment', () {
      final m = MyMethodMeta(
        'getById',
        'Future<User?>',
        [MyParamMeta('id', 'int', null)],
        [],
        true,
        false,
      );
      final field = buildSinglePositionalField(m, 'User?', '', 'user');
      final code = field.assignment.toString();
      expect(code, contains('.family<User?, int>'));
      expect(code, contains('retry: _noProviderRetry'));
    });

    test('nullable param type works correctly in assignment', () {
      final m = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [MyParamMeta('filter', 'String?', null)],
        [],
        true,
        false,
      );
      final field = buildSinglePositionalField(m, 'List<Item>', '', 'items');
      final code = field.assignment.toString();
      expect(code, contains('.family<List<Item>, String?>'));
    });
  });

  group('buildSingleNamedField', () {
    test('generates AutoDisposeFutureProviderFamily field', () {
      final m = MyMethodMeta(
        'getByFilter',
        'Future<List<Item>>',
        [],
        [MyParamMeta('filter', 'String?', null)],
        false,
        true,
      );
      final field = buildSingleNamedField(m, 'List<Item>', '', 'items');
      expect(field.static, isTrue);
      final code = field.assignment.toString();
      expect(code, contains('.family<List<Item>, String?>'));
    });

    test('param type correctly reflected in family assignment', () {
      final m = MyMethodMeta(
        'getByFilter',
        'Future<List<Item>>',
        [],
        [MyParamMeta('filter', 'String?', null)],
        false,
        true,
      );
      final field = buildSingleNamedField(m, 'List<Item>', '', 'items');
      final code = field.assignment.toString();
      expect(code, contains('filter: filter'));
    });
  });

  group('buildMixedOrMultiParamField', () {
    test('generates AutoDisposeFutureProviderFamily with record type', () {
      final m = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [MyParamMeta('query', 'String', null)],
        [MyParamMeta('filter', 'String?', null)],
        true,
        true,
      );
      final field = buildMixedOrMultiParamField(m, 'List<Item>', '', 'items');
      expect(field.static, isTrue);
      final code = field.assignment.toString();
      expect(code, contains('FutureProvider.autoDispose.family<List<Item>'));
    });

    test('record type includes both positional and named', () {
      final m = MyMethodMeta(
        'search',
        'Future<List<Item>>',
        [MyParamMeta('query', 'String', null)],
        [MyParamMeta('filter', 'String?', null)],
        true,
        true,
      );
      final field = buildMixedOrMultiParamField(m, 'List<Item>', '', 'items');
      final code = field.assignment.toString();
      expect(code, contains('query'));
      expect(code, contains('filter: filter'));
    });

    test('multiple named params uses record syntax', () {
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
      final field = buildMixedOrMultiParamField(m, 'List<Item>', '', 'items');
      final code = field.assignment.toString();
      expect(code, contains('filterFrom: filterFrom'));
      expect(code, contains('filterTo: filterTo'));
    });
  });

  group('buildRecordTypeAndDestructure', () {
    MyMethodMeta makeMethod({
      List<MyParamMeta> positionalParams = const [],
      List<MyParamMeta> namedParams = const [],
    }) {
      return MyMethodMeta(
        'test',
        'Future<void>',
        positionalParams,
        namedParams,
        positionalParams.isNotEmpty,
        namedParams.isNotEmpty,
      );
    }

    test('no params returns empty record type', () {
      final m = makeMethod();
      final info = buildRecordTypeAndDestructure(m);
      expect(info.recordType, '()');
      expect(info.destructuredVars, isEmpty);
      expect(info.methodCall, isEmpty);
    });

    test('single positional returns simple type', () {
      final m = makeMethod(positionalParams: [MyParamMeta('id', 'int', null)]);
      final info = buildRecordTypeAndDestructure(m);
      expect(info.recordType, 'int');
      expect(info.destructuredVars, contains('final id = args;'));
      expect(info.methodCall, 'id');
    });

    test('multiple positional returns tuple record', () {
      final m = makeMethod(
        positionalParams: [
          MyParamMeta('a', 'int', null),
          MyParamMeta('b', 'String', null),
        ],
      );
      final info = buildRecordTypeAndDestructure(m);
      expect(info.recordType, '(int, String)');
      expect(info.methodCall, 'a, b');
    });

    test('single named returns record syntax', () {
      final m = makeMethod(
        namedParams: [MyParamMeta('filter', 'String?', null)],
      );
      final info = buildRecordTypeAndDestructure(m);
      expect(info.recordType, '({String? filter})');
      expect(info.methodCall, 'filter: filter');
    });

    test('multiple named returns proper record syntax', () {
      final m = makeMethod(
        namedParams: [
          MyParamMeta('a', 'int', null),
          MyParamMeta('b', 'String?', null),
        ],
      );
      final info = buildRecordTypeAndDestructure(m);
      expect(info.recordType, '({int a, String? b})');
      expect(info.methodCall, 'a: a, b: b');
    });

    test('mixed positional and named', () {
      final m = makeMethod(
        positionalParams: [MyParamMeta('query', 'String', null)],
        namedParams: [MyParamMeta('filter', 'String?', null)],
      );
      final info = buildRecordTypeAndDestructure(m);
      expect(info.recordType, contains('String'));
      expect(info.methodCall, contains('filter: filter'));
    });
  });
}
