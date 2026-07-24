import 'package:riverpod_for_serverpod_generator/src/build_invalidate_hook.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('buildInvalidateHookSource', () {
    MyMethodMeta listChildren() => MyMethodMeta(
          'listChildren',
          'Future<List<ChildRow>>',
          [MyParamMeta('parentId', 'String', null)],
          [],
          true,
          false,
          innerProviderName: 'RefSelectorEndpoint',
        );

    MyMethodMeta getSelection() => MyMethodMeta(
          'getSelection',
          'Future<SelectionSnapshot>',
          [MyParamMeta('parentId', 'String', null)],
          [],
          true,
          false,
          innerProviderName: 'RefSelectorEndpoint',
        );

    MyMethodMeta listEvents() => MyMethodMeta(
          'listEvents',
          'Future<List<Event>>',
          [],
          [],
          false,
          false,
          innerProviderName: 'RefEventEndpoint',
        );

    MyMethodMeta searchEvents() => MyMethodMeta(
          'searchEvents',
          'Future<List<Event>>',
          [
            MyParamMeta('query', 'String', null),
            MyParamMeta('limit', 'int', null),
          ],
          [],
          true,
          false,
          innerProviderName: 'RefEventEndpoint',
        );

    test('providerFamily uses invalidate not read for precise target', () {
      final mutation = MyMethodMeta(
        'saveSelection',
        'Future<void>',
        [MyParamMeta('parentId', 'String', null)],
        [],
        true,
        false,
        includeSelfInHook: false,
        innerProviderName: 'RefSelectorEndpoint',
        mutationCommand: const MutationCommandMeta(
          affects: 'SelectionSnapshot',
          invalidate: [
            InvalidateMeta.provider(
              'SelectorEndpoint',
              'listChildren',
              argFrom: 'parentId',
            ),
          ],
        ),
      );
      final endpoints = [
        InvalidateHookEndpoint('SelectorEndpoint', [
          listChildren(),
          mutation,
        ]),
      ];

      final src = buildInvalidateHookSource(
        currentEndpoint: 'SelectorEndpoint',
        method: mutation,
        endpoints: endpoints,
      );

      expect(src, contains('Reader read'));
      expect(src, contains('ProviderInvalidator invalidate'));
      expect(src, contains('String parentId'));
      expect(
        src,
        contains(
          'RefSelectorEndpoint.listChildrenInvalidate(invalidate, parentId)',
        ),
      );
      expect(src, isNot(contains('listChildrenInvalidate(read')));
      expect(src, isNot(contains('updateAll(read)')));
    });

    test('two precise targets mirror selector_demo saveSelection', () {
      final mutation = MyMethodMeta(
        'saveSelection',
        'Future<void>',
        [
          MyParamMeta('parentId', 'String', null),
          MyParamMeta('selectedChildIds', 'List<String>', null),
        ],
        [],
        true,
        false,
        includeSelfInHook: true,
        innerProviderName: 'RefSelectorEndpoint',
        mutationCommand: const MutationCommandMeta(
          affects: 'SelectionSnapshot',
          invalidate: [
            InvalidateMeta.provider(
              'SelectorEndpoint',
              'listChildren',
              argFrom: 'parentId',
            ),
            InvalidateMeta.provider(
              'SelectorEndpoint',
              'getSelection',
              argFrom: 'parentId',
            ),
          ],
        ),
      );
      final endpoints = [
        InvalidateHookEndpoint('SelectorEndpoint', [
          listChildren(),
          getSelection(),
          mutation,
        ]),
      ];

      final src = buildInvalidateHookSource(
        currentEndpoint: 'SelectorEndpoint',
        method: mutation,
        endpoints: endpoints,
      );

      expect(src, contains('RefSelectorEndpoint.updateAll(read);'));
      expect(
        src,
        contains(
          'RefSelectorEndpoint.listChildrenInvalidate(invalidate, parentId)',
        ),
      );
      expect(
        src,
        contains(
          'RefSelectorEndpoint.getSelectionInvalidate(invalidate, parentId)',
        ),
      );
      expect(src, isNot(contains('Invalidate(read')));
    });

    test('provider without argFrom emits InvalidateAll(invalidate)', () {
      final mutation = MyMethodMeta(
        'clearEvents',
        'Future<void>',
        [],
        [],
        false,
        false,
        includeSelfInHook: false,
        innerProviderName: 'RefEventEndpoint',
        mutationCommand: const MutationCommandMeta(
          affects: 'Event',
          invalidate: [
            InvalidateMeta.provider('EventEndpoint', 'listEvents'),
          ],
        ),
      );
      final endpoints = [
        InvalidateHookEndpoint('EventEndpoint', [listEvents(), mutation]),
      ];

      final src = buildInvalidateHookSource(
        currentEndpoint: 'EventEndpoint',
        method: mutation,
        endpoints: endpoints,
      );

      expect(
        src,
        contains('RefEventEndpoint.listEventsInvalidateAll(invalidate)'),
      );
      expect(src, isNot(contains('listEventsInvalidate(read')));
      expect(src, isNot(contains('updateAll(read)')));
    });

    test('argFrom with multi-arg target falls back to InvalidateAll', () {
      final mutation = MyMethodMeta(
        'bump',
        'Future<void>',
        [MyParamMeta('query', 'String', null)],
        [],
        true,
        false,
        includeSelfInHook: false,
        innerProviderName: 'RefEventEndpoint',
        mutationCommand: const MutationCommandMeta(
          affects: 'Event',
          invalidate: [
            InvalidateMeta.provider(
              'EventEndpoint',
              'searchEvents',
              argFrom: 'query',
            ),
          ],
        ),
      );
      final endpoints = [
        InvalidateHookEndpoint('EventEndpoint', [searchEvents(), mutation]),
      ];

      final src = buildInvalidateHookSource(
        currentEndpoint: 'EventEndpoint',
        method: mutation,
        endpoints: endpoints,
      );

      expect(
        src,
        contains('RefEventEndpoint.searchEventsInvalidateAll(invalidate)'),
      );
      expect(src, isNot(contains('searchEventsInvalidate(invalidate, query)')));
    });

    test('self and endpoint still use updateAll(read)', () {
      final mutation = MyMethodMeta(
        'updateRole',
        'Future<void>',
        [],
        [],
        false,
        false,
        includeSelfInHook: false,
        innerProviderName: 'RefAdminEndpoint',
        mutationCommand: const MutationCommandMeta(
          affects: 'User',
          invalidate: [
            InvalidateMeta.self('AdminEndpoint'),
            InvalidateMeta.endpoint('UserEndpoint'),
          ],
        ),
      );
      final endpoints = [
        InvalidateHookEndpoint('AdminEndpoint', [mutation]),
        const InvalidateHookEndpoint('UserEndpoint', []),
      ];

      final src = buildInvalidateHookSource(
        currentEndpoint: 'AdminEndpoint',
        method: mutation,
        endpoints: endpoints,
      );

      expect(src, contains('RefAdminEndpoint.updateAll(read);'));
      expect(src, contains('RefUserEndpoint.updateAll(read);'));
    });
  });
}
