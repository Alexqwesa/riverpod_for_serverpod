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
/// connection error). Suitable for V1; a later persistence layer can filter
/// on [idempotent] and only store safe operations.
class InMemoryMutationRetryQueue {
  InMemoryMutationRetryQueue({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, _QueuedMutation> _entries = {};

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
  void schedule({
    required String id,
    required bool idempotent,
    required MutationRetryRunner run,
    Duration initialDelay = Duration.zero,
    String? label,
  }) {
    final when = _now().add(initialDelay);
    _entries[id] = _QueuedMutation(
      id: id,
      label: label,
      idempotent: idempotent,
      run: run,
      nextRetryAt: when,
    );
  }

  /// Removes an entry without running it. Returns whether an entry existed.
  bool cancel(String id) => _entries.remove(id) != null;

  void clear() => _entries.clear();

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
      return MutationRetryAttemptResult.success;
    } catch (e) {
      entry.attemptCount++;
      entry.lastError = e;
      entry.nextRetryAt = _now().add(failureBackoff);
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
}
