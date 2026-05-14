import 'package:riverpod/riverpod.dart';
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('RefreshWarningNotifier', () {
    test('recordFailure increments count and stores source key', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(refreshWarningProvider.notifier)
          .recordFailure(sourceKey: 'RefX.y', error: StateError('boom'));

      final s = container.read(refreshWarningProvider);
      expect(s.hasWarning, isTrue);
      expect(s.failedRefreshCount, 1);
      expect(s.lastSourceKey, 'RefX.y');
      expect(s.lastMessage, contains('boom'));
      expect(s.queuedMutationCount, 0);
    });

    test('recordQueuedMutation stores retry warning details', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final nextRetryAt = DateTime.utc(2026, 5, 13, 12);

      container.read(refreshWarningProvider.notifier).recordQueuedMutation(
            mutationId: 'Admin.updateUser.1',
            queuedMutationCount: 2,
            error: StateError('offline'),
            nextRetryAt: nextRetryAt,
          );

      final s = container.read(refreshWarningProvider);
      expect(s.hasWarning, isTrue);
      expect(s.failedRefreshCount, 0);
      expect(s.queuedMutationCount, 2);
      expect(s.lastMutationId, 'Admin.updateUser.1');
      expect(s.lastMessage, contains('offline'));
      expect(s.nextRetryAt, nextRetryAt);
    });

    test('setQueuedMutationCount clears mutation warning when count is zero',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(refreshWarningProvider.notifier).recordQueuedMutation(
            mutationId: 'm1',
            queuedMutationCount: 1,
          );
      container.read(refreshWarningProvider.notifier).setQueuedMutationCount(0);

      final s = container.read(refreshWarningProvider);
      expect(s.hasWarning, isFalse);
      expect(s.queuedMutationCount, 0);
      expect(s.lastMutationId, isNull);
      expect(s.nextRetryAt, isNull);
    });

    test('clear resets state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(refreshWarningProvider.notifier)
          .recordFailure(sourceKey: 'a', error: 'e');
      container.read(refreshWarningProvider.notifier).clear();

      expect(container.read(refreshWarningProvider).hasWarning, isFalse);
    });

    test('mutationRetryQueueProvider keeps queued warning count in sync',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final queue = container.read(mutationRetryQueueProvider);
      queue.schedule(id: 'm1', idempotent: true, run: () async {});

      expect(container.read(refreshWarningProvider).queuedMutationCount, 1);

      await queue.retryNow('m1');

      final s = container.read(refreshWarningProvider);
      expect(s.queuedMutationCount, 0);
      expect(s.hasWarning, isFalse);
    });
  });
}
