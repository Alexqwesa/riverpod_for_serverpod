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
      expect(mapper.accept(DartEmitter()).toString(), contains('final id = args;'));
    });
  });
}
