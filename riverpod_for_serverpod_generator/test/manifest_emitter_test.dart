import 'package:riverpod_for_serverpod_generator/src/manifest_emitter.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('buildEndpointManifestCode', () {
    test('emits a const typed manifest with query and mutation metadata', () {
      const manifest = EndpointManifestMeta([
        EndpointManifestEntry(
          name: 'AdminEndpoint',
          methods: [
            MethodManifestEntry(
              name: 'listUsersByRole',
              returnType: 'Future<List<UserSummary>>',
              positionalParams: [
                MyParamMeta('roleName', 'String', null),
              ],
              namedParams: [
                MyParamMeta('page', 'int?', 'null'),
              ],
              cachedQuery: CachedQueryMeta(
                entity: 'UserSummary',
                secure: true,
                byIdMethod: 'getUserSummaryById',
              ),
            ),
            MethodManifestEntry(
              name: 'updateUserRole',
              returnType: 'Future<UserSummary>',
              positionalParams: [
                MyParamMeta('userId', 'int', null),
              ],
              namedParams: [],
              mutationCommand: MutationCommandMeta(
                affects: 'UserSummary',
                idArg: 'userId',
                invalidate: [
                  InvalidateMeta.all('listUsersByRole'),
                  InvalidateMeta.family(
                    'getUserSummaryById',
                    argFrom: 'userId',
                  ),
                ],
                optimistic: 'OptimisticPolicy.patchLocalCache',
                refetch: 'RefetchPolicy.mergeReturnedEntity',
                idempotent: true,
              ),
              validateStrings: [
                ValidateStringMeta(
                  arg: 'roleName',
                  notEmpty: true,
                  maxLength: 50,
                ),
              ],
            ),
          ],
        ),
      ]);

      final code = buildEndpointManifestCode(manifest);

      expect(
          code, contains('const generatedEndpointManifest = EndpointManifest'));
      expect(code, contains('name: "AdminEndpoint"'));
      expect(code, contains('entity: "UserSummary"'));
      expect(code, contains('secure: true'));
      expect(code, contains('byIdMethod: "getUserSummaryById"'));
      expect(code, contains('mutationCommand: MutationCommandInfo'));
      expect(code, contains('family: true'));
      expect(code, contains('optimistic: OptimisticPolicy.patchLocalCache'));
      expect(code, contains('maxLength: 50'));
    });

    test('escapes strings for Dart source', () {
      const manifest = EndpointManifestMeta([
        EndpointManifestEntry(
          name: 'Quote"Endpoint',
          methods: [
            MethodManifestEntry(
              name: 'lineBreak',
              returnType: 'Future<String>',
              positionalParams: [
                MyParamMeta('value', 'String', '"quoted"'),
              ],
              namedParams: [],
            ),
          ],
        ),
      ]);

      final code = buildEndpointManifestCode(manifest);

      expect(code, contains(r'Quote\"Endpoint'));
      expect(code, contains(r'\"quoted\"'));
    });
  });
}
