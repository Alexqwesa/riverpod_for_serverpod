import 'package:riverpod_for_serverpod_generator/src/diagnostics.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('validateEndpointManifest', () {
    test('reports conflicting query and mutation annotations', () {
      const manifest = EndpointManifestMeta([
        EndpointManifestEntry(
          name: 'AdminEndpoint',
          methods: [
            MethodManifestEntry(
              name: 'bad',
              returnType: 'Future<UserSummary>',
              positionalParams: [],
              namedParams: [],
              cachedQuery: CachedQueryMeta(entity: 'UserSummary'),
              mutationCommand: MutationCommandMeta(affects: 'UserSummary'),
            ),
          ],
        ),
      ]);

      final diagnostics = validateEndpointManifest(manifest);

      expect(
          diagnostics.map((d) => d.code), contains('conflicting_annotations'));
      expect(diagnostics.first.severity, ManifestDiagnosticSeverity.error);
      expect(diagnostics.first.displayMessage, contains('AdminEndpoint.bad'));
    });

    test(
        'reports unsupported cached query return types and invalid cache config',
        () {
      const manifest = EndpointManifestMeta([
        EndpointManifestEntry(
          name: 'IssueEndpoint',
          methods: [
            MethodManifestEntry(
              name: 'pagedIssues',
              returnType: 'Future<Page<Issue>>',
              positionalParams: [],
              namedParams: [],
              cachedQuery: CachedQueryMeta(
                entity: 'Issue',
                maxItems: 0,
                cacheVersion: 0,
              ),
            ),
          ],
        ),
      ]);

      final codes = validateEndpointManifest(manifest).map((d) => d.code);

      expect(codes, contains('unsupported_cached_return_type'));
      expect(codes, contains('invalid_cache_max_items'));
      expect(codes, contains('invalid_cache_version'));
    });

    test('reports mutation retry and bool refetch risks', () {
      const manifest = EndpointManifestMeta([
        EndpointManifestEntry(
          name: 'AdminEndpoint',
          methods: [
            MethodManifestEntry(
              name: 'updateRole',
              returnType: 'Future<bool>',
              positionalParams: [],
              namedParams: [],
              mutationCommand: MutationCommandMeta(
                affects: 'UserSummary',
                retry: 'RetryPolicy.connectionOnly',
                idempotent: false,
                idempotencyKeyArg: 'clientRequestId',
                refetch: 'RefetchPolicy.byId',
              ),
            ),
          ],
        ),
      ]);

      final codes = validateEndpointManifest(manifest).map((d) => d.code);

      expect(codes, contains('retry_requires_idempotent'));
      expect(codes, contains('idempotency_key_without_idempotent'));
      expect(codes, contains('bool_mutation_requires_by_id'));
    });

    test('warns when create retry has no idempotency key', () {
      const manifest = EndpointManifestMeta([
        EndpointManifestEntry(
          name: 'IssueEndpoint',
          methods: [
            MethodManifestEntry(
              name: 'createIssue',
              returnType: 'Future<Issue>',
              positionalParams: [],
              namedParams: [],
              mutationCommand: MutationCommandMeta(
                affects: 'Issue',
                retry: 'RetryPolicy.connectionOnly',
                idempotent: true,
                refetch: 'RefetchPolicy.none',
              ),
            ),
          ],
        ),
      ]);

      final diagnostics = validateEndpointManifest(manifest);

      expect(
        diagnostics.map((d) => d.code),
        contains('create_retry_requires_idempotency_key'),
      );
      expect(diagnostics.single.severity, ManifestDiagnosticSeverity.warning);
    });

    test('accepts create mutation retry with idempotency key', () {
      const manifest = EndpointManifestMeta([
        EndpointManifestEntry(
          name: 'IssueEndpoint',
          methods: [
            MethodManifestEntry(
              name: 'createIssue',
              returnType: 'Future<Issue>',
              positionalParams: [],
              namedParams: [],
              mutationCommand: MutationCommandMeta(
                affects: 'Issue',
                retry: 'RetryPolicy.connectionOnly',
                idempotent: true,
                idempotencyKeyArg: 'clientRequestId',
                refetch: 'RefetchPolicy.none',
              ),
            ),
            MethodManifestEntry(
              name: 'addIssueDraft',
              returnType: 'Future<Issue>',
              positionalParams: [],
              namedParams: [],
              mutationCommand: MutationCommandMeta(
                affects: 'Issue',
                retry: 'RetryPolicy.none',
                idempotent: false,
                refetch: 'RefetchPolicy.none',
              ),
            ),
          ],
        ),
      ]);

      expect(validateEndpointManifest(manifest), isEmpty);
    });

    test('warns when mutation-like method has no MutationCommand', () {
      const manifest = EndpointManifestMeta([
        EndpointManifestEntry(
          name: 'AdminEndpoint',
          methods: [
            MethodManifestEntry(
              name: 'updateRole',
              returnType: 'Future<void>',
              positionalParams: [],
              namedParams: [],
            ),
          ],
        ),
      ]);

      final diagnostics = validateEndpointManifest(manifest);

      expect(
        diagnostics.map((d) => d.code),
        contains('mutation_like_method_missing_annotation'),
      );
      expect(diagnostics.single.severity, ManifestDiagnosticSeverity.warning);
    });

    test('does not warn for explicitly annotated mutation-like methods', () {
      const manifest = EndpointManifestMeta([
        EndpointManifestEntry(
          name: 'AdminEndpoint',
          methods: [
            MethodManifestEntry(
              name: 'updateRole',
              returnType: 'Future<void>',
              positionalParams: [],
              namedParams: [],
              mutationCommand: MutationCommandMeta(
                affects: 'UserSummary',
                retry: 'RetryPolicy.none',
              ),
            ),
            MethodManifestEntry(
              name: 'setRoleOptions',
              returnType: 'Future<List<Role>>',
              positionalParams: [],
              namedParams: [],
              cachedQuery: CachedQueryMeta(entity: 'Role'),
            ),
          ],
        ),
      ]);

      expect(validateEndpointManifest(manifest), isEmpty);
    });

    test('accepts supported safe cached query and mutation metadata', () {
      const manifest = EndpointManifestMeta([
        EndpointManifestEntry(
          name: 'IssueEndpoint',
          methods: [
            MethodManifestEntry(
              name: 'listIssues',
              returnType: 'Future<List<Issue>>',
              positionalParams: [],
              namedParams: [],
              cachedQuery: CachedQueryMeta(entity: 'Issue'),
            ),
            MethodManifestEntry(
              name: 'updateIssue',
              returnType: 'Future<Issue>',
              positionalParams: [],
              namedParams: [],
              mutationCommand: MutationCommandMeta(
                affects: 'Issue',
                retry: 'RetryPolicy.connectionOnly',
                idempotent: true,
              ),
            ),
          ],
        ),
      ]);

      expect(validateEndpointManifest(manifest), isEmpty);
    });
  });
}
