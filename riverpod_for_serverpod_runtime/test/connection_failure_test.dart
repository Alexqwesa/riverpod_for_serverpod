import 'dart:async';

import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('isLikelyConnectionFailure', () {
    test('detects TimeoutException', () {
      expect(isLikelyConnectionFailure(TimeoutException('x')), isTrue);
    });

    test('detects common message patterns', () {
      expect(
        isLikelyConnectionFailure(Exception('Connection refused')),
        isTrue,
      );
      expect(
        isLikelyConnectionFailure(Exception('Unable to reach server')),
        isFalse,
      );
    });
  });

  group('mutationFailureShouldEnqueue', () {
    test('requires retry flag, idempotent, and connection-like error', () {
      expect(
        mutationFailureShouldEnqueue(
          error: TimeoutException('t'),
          idempotent: true,
          retryEnabled: true,
        ),
        isTrue,
      );
      expect(
        mutationFailureShouldEnqueue(
          error: TimeoutException('t'),
          idempotent: false,
          retryEnabled: true,
        ),
        isFalse,
      );
      expect(
        mutationFailureShouldEnqueue(
          error: TimeoutException('t'),
          idempotent: true,
          retryEnabled: false,
        ),
        isFalse,
      );
    });
  });
}
