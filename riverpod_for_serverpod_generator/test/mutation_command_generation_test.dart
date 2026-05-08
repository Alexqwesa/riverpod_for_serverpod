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
          ),
        ],
      );

      expect(code, contains('abstract final class RefAdminEndpointCommands'));
      expect(code, contains('mutationFailureShouldEnqueue'));
      expect(code, contains('read(mutationRetryQueueProvider).schedule'));
      expect(code, contains('invalidateAfterUpdateUserRole'));
      expect(code, contains("'AdminEndpoint.updateUserRole.\$userId'"));
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
}
