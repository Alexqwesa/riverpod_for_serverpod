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
      expect(
        code,
        contains(
          'static const DialogPolicy dialogPolicyAfterUpdateUserRole = DialogPolicy.onSuccessOnly;',
        ),
      );
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
            mergePolicy: 'CacheMergePolicy.refetchById',
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

    test(
      'mergeReturnedEntity refetch + cache mergePolicy refetchById uses by-id refresh',
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
            mergePolicy: 'CacheMergePolicy.refetchById',
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
                refetch: 'RefetchPolicy.mergeReturnedEntity',
              ),
            ),
          ],
          entityCacheTemplates: templates,
          methodToClientField: methodToField,
        );

        expect(code, contains('__mutRefetched'));
        expect(code, contains('getUser'));
        expect(code, isNot(contains('await __mutEntityCache.putOne(result')));
      },
    );

    test(
      'mergeReturnedEntity refetch + cache mergePolicy mergeReturnedEntity uses RPC result',
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
            mergePolicy: 'CacheMergePolicy.mergeReturnedEntity',
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
                refetch: 'RefetchPolicy.mergeReturnedEntity',
              ),
            ),
          ],
          entityCacheTemplates: templates,
          methodToClientField: methodToField,
        );

        expect(code, contains('await __mutEntityCache.putOne(result'));
        expect(code, isNot(contains('__mutRefetched')));
      },
    );

    test(
      'mergeReturnedEntity refetch + cache mergePolicy replaceEntity uses RPC result',
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
            mergePolicy: 'CacheMergePolicy.replaceEntity',
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
                refetch: 'RefetchPolicy.mergeReturnedEntity',
              ),
            ),
          ],
          entityCacheTemplates: templates,
          methodToClientField: methodToField,
        );

        expect(code, contains('await __mutEntityCache.putOne(result'));
        expect(code, isNot(contains('__mutRefetched')));
      },
    );

    test(
      'RefetchPolicy.byId + cache mergePolicy mergeReturnedEntity uses RPC result',
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
            mergePolicy: 'CacheMergePolicy.mergeReturnedEntity',
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
                refetch: 'RefetchPolicy.byId',
              ),
            ),
          ],
          entityCacheTemplates: templates,
          methodToClientField: methodToField,
        );

        expect(code, contains('await __mutEntityCache.putOne(result'));
        expect(code, isNot(contains('__mutRefetched')));
      },
    );

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
