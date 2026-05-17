import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Selector in-memory API', (sessionBuilder, endpoints) {
    test('listParents returns seeded departments', () async {
      final parents = await endpoints.selector.listParents(sessionBuilder);
      expect(parents.map((p) => p.id).toSet(), contains('dept-electronics'));
      expect(parents.length, greaterThanOrEqualTo(2));
    });

    test('saveSelection then getSelection round-trip', () async {
      const p = 'dept-electronics';
      await endpoints.selector.saveSelection(
        sessionBuilder,
        p,
        <String>['c-laptop', 'c-phone'],
      );
      final snap = await endpoints.selector.getSelection(sessionBuilder, p);
      expect(snap.selectedChildIds, containsAll(<String>['c-laptop', 'c-phone']));
    });
  });
}
