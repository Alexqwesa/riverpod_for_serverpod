import 'package:code_builder/code_builder.dart';
import 'package:riverpod_for_serverpod_generator/src/build_provider_invalidator.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('buildProviderInvalidatorMethods variant mapper', () {
    test('multi-positional destructures args before return', () {
      final m = MyMethodMeta(
        'updateUsersRole',
        'Future<bool>',
        [
          MyParamMeta('userIds', 'List<int>', null),
          MyParamMeta('roleName', 'String', null),
        ],
        [],
        true,
        false,
        innerProviderName: 'RefAdminEndpoint',
      );
      final mapper = buildProviderInvalidatorMethods(m).firstWhere(
        (meth) =>
            meth.name != null &&
            meth.name!.endsWith('ToUpdateUsersRoleArgs') &&
            meth.name!.startsWith('updateUsersRole'),
      );
      final src = mapper.accept(DartEmitter()).toString();
      expect(src, contains('final (userIds, roleName) = args;'));
      expect(src, contains('return (userIds, roleName)'));
    });

    test('single positional maps args to parameter name via destructure', () {
      final m = MyMethodMeta(
        'getById',
        'Future<User?>',
        [MyParamMeta('id', 'int', null)],
        [],
        true,
        false,
        innerProviderName: 'RefUserEndpoint',
      );
      final mapper = buildProviderInvalidatorMethods(m).firstWhere(
        (meth) => meth.name != null && meth.name!.contains('ToGetByIdArgs'),
      );
      expect(
        mapper.accept(DartEmitter()).toString(),
        contains('final id = args;'),
      );
    });
  });

  group('buildProviderInvalidatorMethods canonical shapes', () {
    test('zero-arg exact and broad invalidators take ProviderInvalidator', () {
      final m = MyMethodMeta(
        'listRoles',
        'Future<List<Role>>',
        [],
        [],
        false,
        false,
        innerProviderName: 'RefAdminEndpoint',
      );
      final methods = buildProviderInvalidatorMethods(m).toList();
      final exact = methods.firstWhere((m) => m.name == 'listRolesInvalidate');
      final broad =
          methods.firstWhere((m) => m.name == 'listRolesInvalidateAll');

      final exactSrc = exact.accept(DartEmitter()).toString();
      expect(exactSrc, contains('ProviderInvalidator invalidate'));
      expect(exactSrc, contains('invalidate(listRoles);'));

      final broadSrc = broad.accept(DartEmitter()).toString();
      expect(broadSrc, contains('ProviderInvalidator invalidate'));
      expect(broadSrc, contains('invalidate(listRoles);'));
    });

    test('family exact invalidator invalidates provider with args', () {
      final m = MyMethodMeta(
        'getById',
        'Future<User?>',
        [MyParamMeta('id', 'int', null)],
        [],
        true,
        false,
        innerProviderName: 'RefUserEndpoint',
      );
      final exact = buildProviderInvalidatorMethods(m).firstWhere(
        (meth) => meth.name == 'getByIdInvalidate',
      );
      final src = exact.accept(DartEmitter()).toString();
      expect(src, contains('ProviderInvalidator invalidate'));
      expect(src, contains('invalidate(getById(args));'));
    });
  });
}
