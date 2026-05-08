import 'dart:async';

/// Heuristic for transient network failures (works on VM and web without
/// importing `dart:io`).
bool isLikelyConnectionFailure(Object error) {
  if (error is TimeoutException) return true;

  final typeName = error.runtimeType.toString().toLowerCase();
  if (typeName.contains('socket')) return true;
  if (typeName.contains('client') && typeName.contains('exception')) {
    return true;
  }

  final msg = error.toString().toLowerCase();
  return msg.contains('failed host lookup') ||
      msg.contains('connection refused') ||
      msg.contains('network is unreachable') ||
      msg.contains('connection reset') ||
      msg.contains('connection timed out') ||
      msg.contains('connection closed') ||
      msg.contains('socketexception') ||
      msg.contains('clientexception');
}

/// Whether a failed mutation should be queued for retry (V1: in-memory only).
bool mutationFailureShouldEnqueue({
  required Object error,
  required bool idempotent,
  required bool retryEnabled,
}) =>
    retryEnabled && idempotent && isLikelyConnectionFailure(error);
