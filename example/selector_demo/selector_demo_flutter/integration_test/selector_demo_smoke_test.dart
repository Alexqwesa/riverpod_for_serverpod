import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:selector_demo_flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts (Mini server should be running for full flow)', (tester) async {
    await app.bootstrap();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byKey(const Key('app_title')), findsOneWidget);
    expect(find.byKey(const Key('selector_scaffold')), findsOneWidget);

    // With a live server: parent picker. Without: error text.
    final picker = find.byKey(const Key('parent_picker'));
    final error = find.byKey(const Key('parents_error'));
    expect(
      picker.evaluate().isNotEmpty || error.evaluate().isNotEmpty,
      isTrue,
      reason: 'Expected parent_picker or parents_error after boot',
    );
  });
}
