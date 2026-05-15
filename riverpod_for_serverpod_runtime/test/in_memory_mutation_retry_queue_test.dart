import 'package:riverpod/misc.dart' show ProviderListenable;
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

T _rejectingRead<T>(ProviderListenable<T> provider) {
  throw UnimplementedError('$provider');
}

void main() {
  group('InMemoryMutationRetryQueue', () {
    tearDown(MutationRetryReplayRegistry.reset);

    test('schedule and retryNow removes entry on success', () async {
      var runs = 0;
      final queue = InMemoryMutationRetryQueue();

      final snapshot = queue.schedule(
        id: 'm1',
        idempotent: true,
        run: () async {
          runs++;
        },
      );

      expect(snapshot.id, 'm1');
      expect(snapshot.nextRetryAt, isNotNull);
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

    test('persistPayload requires idempotent', () {
      final queue = InMemoryMutationRetryQueue();
      expect(
        () => queue.schedule(
          id: 'x',
          idempotent: false,
          persistPayload: const MutationRetryPersistedPayload(
            opKey: 'A.b',
            args: {},
          ),
          run: () async {},
        ),
        throwsArgumentError,
      );
    });

    test('persists idempotent entries and hydrates replay runners', () async {
      MutationRetryReplayRegistry.register('E.m', (read, args) async {
        expect(args['x'], 1);
      });

      final kv = MemoryGeneratedKeyValueStorage();
      final q1 = InMemoryMutationRetryQueue(
        persistenceStorage: kv,
        onChanged: (_) {},
      );

      q1.schedule(
        id: 'a',
        idempotent: true,
        label: 'm',
        persistPayload: const MutationRetryPersistedPayload(
          opKey: 'E.m',
          args: {'x': 1},
        ),
        run: () async {},
      );

      await Future<void>.delayed(Duration.zero);

      expect(await kv.read(mutationRetryPersistenceStateKey), isNotNull);

      final q2 = InMemoryMutationRetryQueue(
        persistenceStorage: kv,
        onChanged: (_) {},
      );
      await q2.hydrateFromPersistence(_rejectingRead);

      expect(q2.length, 1);
      await q2.retryNow('a');
      expect(q2.isEmpty, isTrue);

      await Future<void>.delayed(Duration.zero);
      expect(await kv.read(mutationRetryPersistenceStateKey), isNull);
    });

    test('onChanged receives pending snapshots after queue changes', () async {
      final changes = <List<String>>[];
      final queue = InMemoryMutationRetryQueue(
        onChanged: (pending) {
          changes.add([for (final snapshot in pending) snapshot.id]);
        },
      );

      queue.schedule(id: 'm1', idempotent: true, run: () async {});
      queue.schedule(id: 'm2', idempotent: true, run: () async {});
      queue.cancel('m1');
      await queue.retryNow('m2');

      expect(changes, [
        ['m1'],
        ['m1', 'm2'],
        ['m2'],
        <String>[],
      ]);
    });
  });
}
