import 'package:meta/meta.dart';

/// Aggregated UI state for failed cached-query refreshes.
@immutable
class RefreshWarningState {
  const RefreshWarningState({
    this.failedRefreshCount = 0,
    this.lastSourceKey,
    this.lastMessage,
    this.lastFailureAt,
  });

  final int failedRefreshCount;
  final String? lastSourceKey;
  final String? lastMessage;
  final DateTime? lastFailureAt;

  bool get hasWarning => failedRefreshCount > 0;
}
