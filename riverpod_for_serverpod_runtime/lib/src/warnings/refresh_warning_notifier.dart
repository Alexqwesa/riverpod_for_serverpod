import 'package:riverpod/riverpod.dart';

import 'refresh_warning_state.dart';

/// Counts failed refreshes and queued mutations so the UI can show a single
/// sync warning banner or retry affordance.
class RefreshWarningNotifier extends Notifier<RefreshWarningState> {
  @override
  RefreshWarningState build() => const RefreshWarningState();

  void recordFailure({required String sourceKey, Object? error}) {
    final prev = state;
    state = RefreshWarningState(
      failedRefreshCount: prev.failedRefreshCount + 1,
      queuedMutationCount: prev.queuedMutationCount,
      lastSourceKey: sourceKey,
      lastMessage: error?.toString(),
      lastFailureAt: DateTime.now(),
      lastMutationId: prev.lastMutationId,
      nextRetryAt: prev.nextRetryAt,
    );
  }

  void recordQueuedMutation({
    required String mutationId,
    required int queuedMutationCount,
    Object? error,
    DateTime? nextRetryAt,
  }) {
    final prev = state;
    state = RefreshWarningState(
      failedRefreshCount: prev.failedRefreshCount,
      queuedMutationCount: queuedMutationCount,
      lastSourceKey: prev.lastSourceKey,
      lastMessage: error?.toString() ?? prev.lastMessage,
      lastFailureAt: DateTime.now(),
      lastMutationId: mutationId,
      nextRetryAt: nextRetryAt,
    );
  }

  void setQueuedMutationCount(
    int queuedMutationCount, {
    DateTime? nextRetryAt,
  }) {
    final prev = state;
    state = RefreshWarningState(
      failedRefreshCount: prev.failedRefreshCount,
      queuedMutationCount: queuedMutationCount,
      lastSourceKey: prev.lastSourceKey,
      lastMessage: prev.lastMessage,
      lastFailureAt: prev.lastFailureAt,
      lastMutationId: queuedMutationCount == 0 ? null : prev.lastMutationId,
      nextRetryAt: queuedMutationCount == 0 ? null : nextRetryAt,
    );
  }

  void clearRefreshFailures() {
    final prev = state;
    state = RefreshWarningState(
      queuedMutationCount: prev.queuedMutationCount,
      lastMutationId: prev.lastMutationId,
      nextRetryAt: prev.nextRetryAt,
    );
  }

  void clear() {
    state = const RefreshWarningState();
  }
}

/// Shared notifier counting failed [@CachedQuery] refreshes.
final refreshWarningProvider =
    NotifierProvider<RefreshWarningNotifier, RefreshWarningState>(
  RefreshWarningNotifier.new,
);
