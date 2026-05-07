import 'package:riverpod_for_serverpod_generator/src/manifest_builder.dart';
import 'package:test/test.dart';

void main() {
  group('buildEndpointManifestFromSource', () {
    test('builds endpoint and method metadata from Serverpod endpoints', () {
      const source = '''
class AdminEndpoint extends Endpoint {
  @CachedQuery(
    entity: UserSummary,
    secure: true,
    byIdMethod: 'getUserSummaryById',
  )
  Future<List<UserSummary>> listUsersByRole(
    Session session,
    String roleName, {
    int? page,
  }) async {
    return [];
  }

  @ValidateString(arg: 'roleName', notEmpty: true, maxLength: 50)
  @MutationCommand(
    affects: UserSummary,
    idArg: 'userId',
    invalidate: [
      Invalidate.all('listUsersByRole'),
      Invalidate.family('getUserSummaryById', argFrom: 'userId'),
    ],
    optimistic: OptimisticPolicy.patchLocalCache,
    refetch: RefetchPolicy.mergeReturnedEntity,
    idempotent: true,
  )
  Future<UserSummary> updateUserRole(
    serverpod.Session session,
    int userId,
    String roleName,
  ) async {
    return UserSummary();
  }
}
''';

      final manifest = buildEndpointManifestFromSource(content: source);

      expect(manifest.endpoints, hasLength(1));
      final endpoint = manifest.endpoints.single;
      expect(endpoint.name, 'AdminEndpoint');
      expect(endpoint.methods, hasLength(2));

      final query = endpoint.methods.first;
      expect(query.name, 'listUsersByRole');
      expect(query.returnType, 'Future<List<UserSummary>>');
      expect(query.positionalParams.map((p) => p.name), ['roleName']);
      expect(query.namedParams.single.name, 'page');
      expect(query.namedParams.single.defaultValue, 'null');
      expect(query.cachedQuery, isNotNull);
      expect(query.cachedQuery!.entity, 'UserSummary');
      expect(query.cachedQuery!.secure, isTrue);
      expect(query.cachedQuery!.byIdMethod, 'getUserSummaryById');
      expect(query.mutationCommand, isNull);

      final mutation = endpoint.methods.last;
      expect(mutation.name, 'updateUserRole');
      expect(mutation.cachedQuery, isNull);
      expect(mutation.mutationCommand, isNotNull);
      expect(mutation.mutationCommand!.affects, 'UserSummary');
      expect(mutation.mutationCommand!.idArg, 'userId');
      expect(mutation.mutationCommand!.invalidate, hasLength(2));
      expect(mutation.mutationCommand!.invalidate.last.family, isTrue);
      expect(mutation.mutationCommand!.optimistic,
          'OptimisticPolicy.patchLocalCache');
      expect(mutation.mutationCommand!.refetch,
          'RefetchPolicy.mergeReturnedEntity');
      expect(mutation.mutationCommand!.idempotent, isTrue);
      expect(mutation.validateStrings.single.arg, 'roleName');
      expect(mutation.validateStrings.single.notEmpty, isTrue);
      expect(mutation.validateStrings.single.maxLength, 50);
    });

    test(
        'skips non-endpoints, private endpoints, ignored methods, and non-session methods',
        () {
      const source = '''
class PlainClass {
  Future<String> nope(Session session) async => '';
}

class _PrivateEndpoint extends Endpoint {
  Future<String> nope(Session session) async => '';
}

@DoNotGenerate()
class IgnoredEndpoint extends Endpoint {
  Future<String> nope(Session session) async => '';
}

class AdminEndpoint extends Endpoint {
  Future<String> noSession(String value) async => value;

  @DoNotGenerate()
  Future<String> ignored(Session session) async => '';

  Future<String> visible(Session session) async => '';
}
''';

      final manifest = buildEndpointManifestFromSource(content: source);

      expect(manifest.endpoints, hasLength(1));
      expect(manifest.endpoints.single.name, 'AdminEndpoint');
      expect(manifest.endpoints.single.methods.map((m) => m.name), ['visible']);
    });
  });
}
