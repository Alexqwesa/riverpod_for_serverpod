import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('EndpointManifest', () {
    const manifest = EndpointManifest(
      endpoints: [
        EndpointInfo(
          name: 'AdminEndpoint',
          methods: [
            MethodInfo(
              name: 'listUsers',
              returnType: 'Future<List<UserSummary>>',
              positionalParams: [
                ParamInfo(name: 'roleName', type: 'String'),
              ],
              namedParams: [
                ParamInfo(name: 'page', type: 'int?', defaultValue: 'null'),
              ],
              cachedQuery: CachedQueryInfo(
                entity: 'UserSummary',
                ttl: Duration(minutes: 5),
                secure: true,
                byIdMethod: 'getUserSummaryById',
                mergePolicy: CacheMergePolicy.replaceEntity,
              ),
              validateStrings: [
                ValidateStringInfo(
                  arg: 'roleName',
                  notEmpty: true,
                  maxLength: 50,
                ),
              ],
            ),
            MethodInfo(
              name: 'updateUser',
              returnType: 'Future<UserSummary>',
              positionalParams: [
                ParamInfo(name: 'userId', type: 'int'),
              ],
              namedParams: [],
              mutationCommand: MutationCommandInfo(
                affects: 'UserSummary',
                idArg: 'userId',
                optimistic: OptimisticPolicy.patchLocalCache,
                retry: RetryPolicy.connectionOnly,
                refetch: RefetchPolicy.mergeReturnedEntity,
                idempotent: true,
                closeDialog: DialogPolicy.onSuccessOnly,
                invalidate: [
                  InvalidateInfo.all('listUsers'),
                  InvalidateInfo.endpoint('UserEndpoint'),
                  InvalidateInfo.family(
                    'getUserSummaryById',
                    argFrom: 'userId',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    test('finds endpoints, methods, and params by name', () {
      final endpoint = manifest.endpointByName('AdminEndpoint');
      final method = endpoint!.methodByName('listUsers');

      expect(endpoint.name, 'AdminEndpoint');
      expect(method!.paramByName('page')!.defaultValue, 'null');
      expect(manifest.endpointByName('MissingEndpoint'), isNull);
      expect(endpoint.methodByName('missingMethod'), isNull);
      expect(method.paramByName('missingParam'), isNull);
    });

    test('stores cached query metadata as typed values', () {
      final cachedQuery = manifest
          .endpointByName('AdminEndpoint')!
          .methodByName('listUsers')!
          .cachedQuery!;

      expect(cachedQuery.entity, 'UserSummary');
      expect(cachedQuery.ttl, const Duration(minutes: 5));
      expect(cachedQuery.secure, isTrue);
      expect(cachedQuery.mergePolicy, CacheMergePolicy.replaceEntity);
    });

    test('stores mutation command metadata as typed values', () {
      final mutation = manifest
          .endpointByName('AdminEndpoint')!
          .methodByName('updateUser')!
          .mutationCommand!;

      expect(mutation.affects, 'UserSummary');
      expect(mutation.optimistic, OptimisticPolicy.patchLocalCache);
      expect(mutation.refetch, RefetchPolicy.mergeReturnedEntity);
      expect(mutation.invalidate[1].endpoint, 'UserEndpoint');
      expect(mutation.invalidate[1].kind, InvalidateKind.endpoint);
      expect(mutation.invalidate.last.family, isTrue);
    });
  });
}
