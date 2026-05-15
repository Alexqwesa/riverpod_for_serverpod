import 'package:riverpod_for_serverpod_generator/src/build_mutation_command.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('buildMutationCommandsClass', () {
    test('emits command class with queue wiring', () {
      final code = buildMutationCommandsClass(
        endpointClassName: 'AdminEndpoint',
        clientField: 'admin',
        mutationMethods: [
          MyMethodMeta(
            'updateUserRole',
            'Future<UserSummary>',
            [MyParamMeta('userId', 'int', null)],
            [MyParamMeta('roleName', 'String', null)],
            true,
            true,
            innerProviderName: 'RefAdminEndpoint',
            timeout: 'Duration(seconds: 60)',
            mutationCommand: MutationCommandMeta(
              affects: 'UserSummary',
              idArg: 'userId',
              idempotent: true,
              retry: 'RetryPolicy.connectionOnly',
            ),
            validateStrings: [
              ValidateStringMeta(
                arg: 'roleName',
                notEmpty: true,
                maxLength: 50,
              ),
            ],
          ),
        ],
      );

      expect(code, contains('abstract final class RefAdminEndpointCommands'));
      expect(code, contains('validateGeneratedString'));
      expect(code, contains('mutationFailureShouldEnqueue'));
      expect(
        code,
        contains(
          'final retrySnapshot = read(mutationRetryQueueProvider).schedule',
        ),
      );
      expect(code, contains('recordQueuedMutation'));
      expect(
          code,
          contains(
              'queuedMutationCount: read(mutationRetryQueueProvider).length'));
      expect(code, contains('MutationRetryPersistedPayload'));
      expect(code, contains('persistPayload:'));
      expect(code, contains("'AdminEndpoint.updateUserRole'"));
      expect(code, contains('invalidateAfterUpdateUserRole'));
      expect(code, contains("'AdminEndpoint.updateUserRole.\$userId'"));
    });

    test('with entity cache template and optimistic policy, opens GeneratedEntityCache',
        () {
      final templates = {
        'UserSummary': const EntityCacheTemplate(
          elementType: 'UserSummary',
          entityTypeKey: 'UserSummary',
          idField: 'id',
          cacheVersion: 1,
          maxItems: 100,
          secure: false,
          byIdMethod: 'getUser',
        ),
      };
      final methodToField = {'getUser': 'admin'};
      final code = buildMutationCommandsClass(
        endpointClassName: 'AdminEndpoint',
        clientField: 'admin',
        mutationMethods: [
          MyMethodMeta(
            'updateUserRole',
            'Future<UserSummary>',
            [MyParamMeta('userId', 'int', null)],
            [MyParamMeta('roleName', 'String', null)],
            true,
            true,
            innerProviderName: 'RefAdminEndpoint',
            mutationCommand: const MutationCommandMeta(
              affects: 'UserSummary',
              idArg: 'userId',
              optimistic: 'OptimisticPolicy.patchLocalCache',
              refetch: 'RefetchPolicy.byId',
            ),
          ),
        ],
        entityCacheTemplates: templates,
        methodToClientField: methodToField,
      );

      expect(code, contains('GeneratedEntityCache<UserSummary>'));
      expect(code, contains('__mutOptimisticPrev'));
      expect(code, contains('getUser'));
      expect(code, contains('__mutRefetched'));
    });

    test('returns empty string when no mutations', () {
      expect(
        buildMutationCommandsClass(
          endpointClassName: 'AdminEndpoint',
          clientField: 'admin',
          mutationMethods: const [],
        ),
        isEmpty,
      );
    });
  });

  group('buildMutationControllerSource', () {
    test('emits AsyncNotifier controller that delegates to commands', () {
      final code = buildMutationControllerSource(
        endpointClassName: 'AdminEndpoint',
        mutationMethods: [
          MyMethodMeta(
            'updateUserRole',
            'Future<UserSummary>',
            [MyParamMeta('userId', 'int', null)],
            [MyParamMeta('roleName', 'String', null)],
            true,
            true,
            innerProviderName: 'RefAdminEndpoint',
            mutationCommand: const MutationCommandMeta(
              affects: 'UserSummary',
            ),
          ),
        ],
      );

      expect(code, contains('adminMutationControllerProvider'));
      expect(code,
          contains('AsyncNotifierProvider<AdminMutationController, void>'));
      expect(
          code,
          contains(
              'final class AdminMutationController extends AsyncNotifier<void>'));
      expect(code, contains('state = const AsyncLoading();'));
      expect(code, contains('state = await AsyncValue.guard'));
      expect(
        code,
        contains(
          'await RefAdminEndpointCommands.updateUserRole(ref.read, userId, roleName);',
        ),
      );
    });

    test('returns empty string when no mutations', () {
      expect(
        buildMutationControllerSource(
          endpointClassName: 'AdminEndpoint',
          mutationMethods: const [],
        ),
        isEmpty,
      );
    });
  });
}
