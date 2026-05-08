import 'package:riverpod/riverpod.dart';
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('RefreshWarningNotifier', () {
    test('recordFailure increments count and stores source key', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(refreshWarningProvider.notifier)
          .recordFailure(sourceKey: 'RefX.y', error: StateError('boom'));

      final s = container.read(refreshWarningProvider);
      expect(s.hasWarning, isTrue);
      expect(s.failedRefreshCount, 1);
      expect(s.lastSourceKey, 'RefX.y');
      expect(s.lastMessage, contains('boom'));
    });

    test('clear resets state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(refreshWarningProvider.notifier)
          .recordFailure(sourceKey: 'a', error: 'e');
      container.read(refreshWarningProvider.notifier).clear();

      expect(container.read(refreshWarningProvider).hasWarning, isFalse);
    });
  });
}
