import 'dart:async';

import 'package:riverpod/misc.dart' show ProviderListenable;
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_for_serverpod_runtime/src/cache/generated_key_value_storage.dart';
import 'package:riverpod_for_serverpod_runtime/src/retry/mutation_retry_persistence.dart';
import 'package:riverpod_for_serverpod_runtime/src/warnings/refresh_warning_notifier.dart';

/// Same shape as generated `Reader`: `ref.read` from a [Ref].
typedef MutationReader = T Function<T>(ProviderListenable<T> provider);

typedef MutationReplayFn =
    Future<void> Function(MutationReader read, Map<String, Object?> args);

/// Registers how to replay mutations stored by [InMemoryMutationRetryQueue].
class MutationRetryReplayRegistry {
  static final Map<String, MutationReplayFn> _replayByOpKey = {};

  static void register(String opKey, MutationReplayFn replay) {
    _replayByOpKey[opKey] = replay;
  }

  /// Clears all registrations (mainly for tests).
  static void reset() => _replayByOpKey.clear();

  static MutationReplayFn? lookup(String opKey) => _replayByOpKey[opKey];
}

/// Result of attempting to run a single queued mutation.
enum MutationRetryAttemptResult {
  /// The runner completed without throwing and the entry was removed.
  success,

  /// The runner threw; the entry remains scheduled for a later attempt.
  failed,

  /// No entry existed for the given id.
  notFound,
}

/// Read-only view of a queued mutation for UI or logging.
class MutationRetrySnapshot {
  final String id;
  final String? label;
  final bool idempotent;
  final int attemptCount;
  final DateTime? nextRetryAt;
  final Object? lastError;

  const MutationRetrySnapshot({
    required this.id,
    this.label,
    required this.idempotent,
    required this.attemptCount,
    this.nextRetryAt,
    this.lastError,
  });
}

typedef MutationRetryRunner = Future<void> Function();
typedef MutationRetryQueueChanged = void Function(
  List<MutationRetrySnapshot> pending,
);

class _QueuedMutation {
  _QueuedMutation({
    required this.id,
    this.label,
    required this.idempotent,
    required this.run,
    required this.nextRetryAt,
  });

  final String id;
  final String? label;
  final bool idempotent;
  final MutationRetryRunner run;
  int attemptCount = 0;
  DateTime? nextRetryAt;
  Object? lastError;

  MutationRetrySnapshot toSnapshot() => MutationRetrySnapshot(
        id: id,
        label: label,
        idempotent: idempotent,
        attemptCount: attemptCount,
        nextRetryAt: nextRetryAt,
        lastError: lastError,
      );
}

/// In-memory queue for re-running failed mutations (for example after a
/// connection error). Optionally persists **idempotent** entries with a
/// [MutationRetryPersistedPayload] through [persistenceStorage].
class InMemoryMutationRetryQueue {
  InMemoryMutationRetryQueue({
    DateTime Function()? now,
    MutationRetryQueueChanged? onChanged,
    GeneratedKeyValueStorage? persistenceStorage,
  })  : _now = now ?? DateTime.now,
        _onChanged = onChanged,
        _persistenceStorage = persistenceStorage;

  final DateTime Function() _now;
  final MutationRetryQueueChanged? _onChanged;
  final GeneratedKeyValueStorage? _persistenceStorage;
  final Map<String, _QueuedMutation> _entries = {};
  final Map<String, MutationRetryPersistedPayload> _persistPayloads = {};
  bool _hydratedFromDisk = false;

  bool get isEmpty => _entries.isEmpty;

  int get length => _entries.length;

  /// Entries sorted by [MutationRetrySnapshot.nextRetryAt] then id.
  List<MutationRetrySnapshot> get pending {
    final list = _entries.values.map((e) => e.toSnapshot()).toList();
    list.sort((a, b) {
      final at = a.nextRetryAt;
      final bt = b.nextRetryAt;
      if (at == null && bt == null) return a.id.compareTo(b.id);
      if (at == null) return -1;
      if (bt == null) return 1;
      final c = at.compareTo(bt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return list;
  }

  /// Schedules or replaces a mutation. The next eligible attempt time is
  /// [initialDelay] after "now" (see constructor).
  ///
  /// When [persistPayload] is set, [idempotent] must be true and the entry can
  /// be written to [persistenceStorage] for replay after restart.
  MutationRetrySnapshot schedule({
    required String id,
    required bool idempotent,
    required MutationRetryRunner run,
    Duration initialDelay = Duration.zero,
    String? label,
    MutationRetryPersistedPayload? persistPayload,
  }) {
    if (persistPayload != null && !idempotent) {
      throw ArgumentError(
        'persistPayload requires idempotent mutations.',
      );
    }
    final when = _now().add(initialDelay);
    final entry = _QueuedMutation(
      id: id,
      label: label,
      idempotent: idempotent,
      run: run,
      nextRetryAt: when,
    );
    _entries[id] = entry;
    if (persistPayload != null) {
      _persistPayloads[id] = persistPayload;
    } else {
      _persistPayloads.remove(id);
    }
    _notifyChanged();
    return entry.toSnapshot();
  }

  /// Loads persisted idempotent entries from [persistenceStorage]. Safe to
  /// call once; later calls no-op. [read] must match the generator `Reader`.
  Future<void> hydrateFromPersistence(MutationReader read) async {
    final storage = _persistenceStorage;
    if (storage == null || _hydratedFromDisk) return;
    _hydratedFromDisk = true;
    final raw = await storage.read(mutationRetryPersistenceStateKey);
    if (raw == null || raw.isEmpty) return;

    final list = MutationRetryPersistedEntry.decodeList(raw);
    for (final disk in list) {
      if (_entries.containsKey(disk.id)) continue;
      final replay = MutationRetryReplayRegistry.lookup(disk.payload.opKey);
      if (replay == null) continue;
      final entry = _QueuedMutation(
        id: disk.id,
        label: disk.label,
        idempotent: disk.idempotent,
        run: () => replay(read, disk.payload.args),
        nextRetryAt: disk.nextRetryAt ?? _now(),
      );
      entry.attemptCount = disk.attemptCount;
      _entries[disk.id] = entry;
      _persistPayloads[disk.id] = disk.payload;
    }
    _notifyChanged();
  }

  /// Removes an entry without running it. Returns whether an entry existed.
  bool cancel(String id) {
    final removed = _entries.remove(id) != null;
    if (removed) {
      _persistPayloads.remove(id);
      _notifyChanged();
    }
    return removed;
  }

  void clear() {
    if (_entries.isEmpty && _persistPayloads.isEmpty) return;
    _entries.clear();
    _persistPayloads.clear();
    _notifyChanged();
  }

  /// Runs the mutation for [id]. On success the entry is removed. On failure
  /// [attemptCount] is incremented and [nextRetryAt] is set using
  /// [failureBackoff] from the current clock.
  Future<MutationRetryAttemptResult> retryNow(
    String id, {
    Duration failureBackoff = const Duration(seconds: 30),
  }) async {
    final entry = _entries[id];
    if (entry == null) return MutationRetryAttemptResult.notFound;

    try {
      await entry.run();
      _entries.remove(id);
      _persistPayloads.remove(id);
      _notifyChanged();
      return MutationRetryAttemptResult.success;
    } catch (e) {
      entry.attemptCount++;
      entry.lastError = e;
      entry.nextRetryAt = _now().add(failureBackoff);
      _notifyChanged();
      return MutationRetryAttemptResult.failed;
    }
  }

  /// Retries every entry whose [nextRetryAt] is null or not after [at].
  /// Returns the number of entries that completed successfully and were removed.
  Future<int> retryAllReady({
    DateTime? at,
    Duration failureBackoff = const Duration(seconds: 30),
  }) async {
    final t = at ?? _now();
    final ids = _entries.entries
        .where((e) {
          final when = e.value.nextRetryAt;
          return when == null || !when.isAfter(t);
        })
        .map((e) => e.key)
        .toList();

    var successes = 0;
    for (final id in ids) {
      final r = await retryNow(id, failureBackoff: failureBackoff);
      if (r == MutationRetryAttemptResult.success) successes++;
    }
    return successes;
  }

  Future<void> _flushPersistence() async {
    final storage = _persistenceStorage;
    if (storage == null) return;

    final out = <MutationRetryPersistedEntry>[];
    for (final e in _entries.entries) {
      final payload = _persistPayloads[e.key];
      if (payload == null) continue;
      out.add(
        MutationRetryPersistedEntry(
          id: e.key,
          idempotent: e.value.idempotent,
          label: e.value.label,
          nextRetryAt: e.value.nextRetryAt,
          attemptCount: e.value.attemptCount,
          payload: payload,
        ),
      );
    }

    if (out.isEmpty) {
      await storage.delete(mutationRetryPersistenceStateKey);
    } else {
      await storage.write(
        mutationRetryPersistenceStateKey,
        MutationRetryPersistedEntry.encodeList(out),
      );
    }
  }

  void _notifyChanged() {
    final onChanged = _onChanged;
    if (onChanged != null) onChanged(pending);
    unawaited(_flushPersistence());
  }
}

/// Override with a [GeneratedKeyValueStorage] to persist idempotent retry
/// metadata across app restarts (requires [MutationRetryReplayRegistry] setup
/// from generated registrations).
final mutationRetryPersistenceStorageProvider =
    Provider<GeneratedKeyValueStorage?>((ref) => null);

/// Shared mutation retry queue for generated command helpers.
final mutationRetryQueueProvider = Provider<InMemoryMutationRetryQueue>((ref) {
  ref.keepAlive();
  final storage = ref.watch(mutationRetryPersistenceStorageProvider);
  final queue = InMemoryMutationRetryQueue(
    persistenceStorage: storage,
    onChanged: (pending) {
      ref.read(refreshWarningProvider.notifier).setQueuedMutationCount(
            pending.length,
            nextRetryAt: pending.isEmpty ? null : pending.first.nextRetryAt,
          );
    },
  );

  if (storage != null) {
    scheduleMicrotask(() {
      T read<T>(ProviderListenable<T> provider) => ref.read(provider);
      queue.hydrateFromPersistence(read);
    });
  }

  return queue;
});
