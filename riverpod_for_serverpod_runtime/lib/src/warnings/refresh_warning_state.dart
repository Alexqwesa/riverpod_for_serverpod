import 'package:meta/meta.dart';

/// Aggregated UI state for failed cached-query refreshes.
@immutable
class RefreshWarningState {
  const RefreshWarningState({
    this.failedRefreshCount = 0,
    this.queuedMutationCount = 0,
    this.lastSourceKey,
    this.lastMessage,
    this.lastFailureAt,
    this.lastMutationId,
    this.nextRetryAt,
  });

  final int failedRefreshCount;
  final int queuedMutationCount;
  final String? lastSourceKey;
  final String? lastMessage;
  final DateTime? lastFailureAt;
  final String? lastMutationId;
  final DateTime? nextRetryAt;

  bool get hasWarning => failedRefreshCount > 0 || queuedMutationCount > 0;
}
