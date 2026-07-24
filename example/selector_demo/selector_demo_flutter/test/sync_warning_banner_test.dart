import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:selector_demo_flutter/main.dart';

void main() {
  testWidgets('shows banner and retry button for queued mutations',
      (tester) async {
    var runs = 0;
    final queue = InMemoryMutationRetryQueue();
    queue.schedule(
      id: 'm1',
      idempotent: true,
      initialDelay: Duration.zero,
      run: () async {
        runs++;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mutationRetryQueueProvider.overrideWithValue(queue),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SyncWarningBanner(
              warning: const RefreshWarningState(queuedMutationCount: 1),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('sync_warning_banner')), findsOneWidget);
    expect(find.byKey(const Key('retry_mutations_button')), findsOneWidget);
    expect(find.textContaining('queued mutation'), findsOneWidget);

    await tester.tap(find.byKey(const Key('retry_mutations_button')));
    await tester.pumpAndSettle();

    expect(runs, 1);
    expect(queue.isEmpty, isTrue);
    expect(find.textContaining('Retried'), findsOneWidget);
  });

  testWidgets('hides retry button when only refresh failures', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SyncWarningBanner(
              warning: RefreshWarningState(failedRefreshCount: 2),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('sync_warning_banner')), findsOneWidget);
    expect(find.byKey(const Key('retry_mutations_button')), findsNothing);
    expect(find.textContaining('refresh failure'), findsOneWidget);
  });
}
