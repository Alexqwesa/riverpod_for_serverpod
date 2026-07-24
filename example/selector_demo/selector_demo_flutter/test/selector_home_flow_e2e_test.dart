import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:selector_demo_client/selector_demo_client.dart';
import 'package:selector_demo_flutter/main.dart';

/// Widget e2e that exercises the real generated providers via [clientProvider].
///
/// Full picker→save UI against a live Mini server lives in
/// `integration_test/selector_demo_flow_e2e_test.dart`.
void main() {
  testWidgets('shows parents_error when server is unreachable', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clientProvider.overrideWithValue(
            Client('http://127.0.0.1:1/'),
          ),
          generatedCacheStorageProvider.overrideWith(
            (ref) async => MemoryGeneratedCacheStorage(),
          ),
          mutationRetryQueueProvider.overrideWithValue(
            InMemoryMutationRetryQueue(),
          ),
        ],
        child: const SelectorDemoApp(),
      ),
    );

    // Allow the generated AsyncNotifier to fail the HTTP call.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selector_scaffold')), findsOneWidget);
    expect(find.byKey(const Key('parents_error')), findsOneWidget);
    expect(find.textContaining('Failed to load departments'), findsOneWidget);
    expect(find.byKey(const Key('parent_picker')), findsNothing);
  });
}
