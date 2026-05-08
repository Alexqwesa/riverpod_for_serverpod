import 'package:riverpod/riverpod.dart';

import 'refresh_warning_state.dart';

/// Counts failed refreshes for [@CachedQuery] providers so the UI can show a
/// single banner or retry affordance.
class RefreshWarningNotifier extends Notifier<RefreshWarningState> {
  @override
  RefreshWarningState build() => const RefreshWarningState();

  void recordFailure({required String sourceKey, Object? error}) {
    final prev = state;
    state = RefreshWarningState(
      failedRefreshCount: prev.failedRefreshCount + 1,
      lastSourceKey: sourceKey,
      lastMessage: error?.toString(),
      lastFailureAt: DateTime.now(),
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
