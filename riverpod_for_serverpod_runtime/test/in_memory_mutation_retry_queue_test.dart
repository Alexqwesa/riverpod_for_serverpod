import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryMutationRetryQueue', () {
    test('schedule and retryNow removes entry on success', () async {
      var runs = 0;
      final queue = InMemoryMutationRetryQueue();

      queue.schedule(
        id: 'm1',
        idempotent: true,
        run: () async {
          runs++;
        },
      );

      expect(queue.length, 1);

      final r = await queue.retryNow('m1');

      expect(r, MutationRetryAttemptResult.success);
      expect(runs, 1);
      expect(queue.isEmpty, isTrue);
    });

    test('retryNow keeps entry and bumps attempts on failure', () async {
      final queue = InMemoryMutationRetryQueue();
      var runs = 0;

      queue.schedule(
        id: 'm1',
        idempotent: false,
        run: () async {
          runs++;
          throw StateError('network');
        },
      );

      final r = await queue.retryNow('m1',
          failureBackoff: const Duration(minutes: 1));

      expect(r, MutationRetryAttemptResult.failed);
      expect(runs, 1);
      expect(queue.length, 1);

      final snap = queue.pending.single;
      expect(snap.attemptCount, 1);
      expect(snap.lastError, isA<StateError>());
    });

    test('retryNow returns notFound for unknown id', () async {
      final queue = InMemoryMutationRetryQueue();
      expect(
        await queue.retryNow('missing'),
        MutationRetryAttemptResult.notFound,
      );
    });

    test('retryAllReady runs only due entries', () async {
      var time = DateTime.utc(2026, 5, 8, 12);
      final queue = InMemoryMutationRetryQueue(now: () => time);

      var aRuns = 0;
      var bRuns = 0;

      queue.schedule(
        id: 'due',
        idempotent: true,
        run: () async {
          aRuns++;
        },
        initialDelay: Duration.zero,
      );

      queue.schedule(
        id: 'later',
        idempotent: true,
        run: () async {
          bRuns++;
        },
        initialDelay: const Duration(hours: 1),
      );

      final successes = await queue.retryAllReady(at: time);

      expect(successes, 1);
      expect(aRuns, 1);
      expect(bRuns, 0);
      expect(queue.length, 1);
      expect(queue.pending.single.id, 'later');
    });

    test('cancel removes without running', () async {
      var runs = 0;
      final queue = InMemoryMutationRetryQueue();
      queue.schedule(
        id: 'm1',
        idempotent: true,
        run: () async {
          runs++;
        },
      );

      expect(queue.cancel('m1'), isTrue);
      expect(queue.cancel('m1'), isFalse);
      expect(runs, 0);
      expect(queue.isEmpty, isTrue);
    });

    test('non-idempotent entries can still be queued in memory', () async {
      final queue = InMemoryMutationRetryQueue();
      queue.schedule(
        id: 'risky',
        idempotent: false,
        run: () async {},
      );

      expect(queue.pending.single.idempotent, isFalse);
    });
  });
}
