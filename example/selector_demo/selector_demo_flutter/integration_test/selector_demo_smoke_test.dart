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
  });
}
