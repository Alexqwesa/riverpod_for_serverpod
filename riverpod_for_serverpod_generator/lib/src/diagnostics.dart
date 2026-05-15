import 'package:riverpod_for_serverpod_generator/src/types.dart';

enum ManifestDiagnosticSeverity {
  warning,
  error,
}

class ManifestDiagnostic {
  final ManifestDiagnosticSeverity severity;
  final String endpoint;
  final String method;
  final String code;
  final String message;

  const ManifestDiagnostic({
    required this.severity,
    required this.endpoint,
    required this.method,
    required this.code,
    required this.message,
  });

  String get displayMessage => '[$code] $endpoint.$method: $message';
}

List<ManifestDiagnostic> validateEndpointManifest(
  EndpointManifestMeta manifest,
) {
  final diagnostics = <ManifestDiagnostic>[];
  for (final endpoint in manifest.endpoints) {
    for (final method in endpoint.methods) {
      diagnostics.addAll(_validateMethod(endpoint.name, method));
    }
  }
  return diagnostics;
}

List<ManifestDiagnostic> _validateMethod(
  String endpoint,
  MethodManifestEntry method,
) {
  final diagnostics = <ManifestDiagnostic>[];
  final cachedQuery = method.cachedQuery;
  final mutation = method.mutationCommand;

  if (cachedQuery != null && mutation != null) {
    diagnostics.add(
      _diagnostic(
        endpoint,
        method,
        'conflicting_annotations',
        'Use either @CachedQuery or @MutationCommand, not both.',
        severity: ManifestDiagnosticSeverity.error,
      ),
    );
  }

  if (cachedQuery != null) {
    diagnostics.addAll(_validateCachedQuery(endpoint, method, cachedQuery));
  }

  if (mutation != null) {
    diagnostics.addAll(_validateMutation(endpoint, method, mutation));
  } else if (cachedQuery == null && _looksLikeMutationName(method.name)) {
    diagnostics.add(
      _diagnostic(
        endpoint,
        method,
        'mutation_like_method_missing_annotation',
        'Method name looks like a mutation. Add @MutationCommand or @DoNotGenerate if this should not be generated as a read provider.',
      ),
    );
  }

  return diagnostics;
}

List<ManifestDiagnostic> _validateCachedQuery(
  String endpoint,
  MethodManifestEntry method,
  CachedQueryMeta cachedQuery,
) {
  final diagnostics = <ManifestDiagnostic>[];
  final returnType = _unwrapFuture(method.returnType);

  if (!_isSupportedCachedReturnType(returnType)) {
    diagnostics.add(
      _diagnostic(
        endpoint,
        method,
        'unsupported_cached_return_type',
        'V1 cached queries support T, T?, and List<T>. Found $returnType.',
      ),
    );
  }

  if (cachedQuery.maxItems < 1) {
    diagnostics.add(
      _diagnostic(
        endpoint,
        method,
        'invalid_cache_max_items',
        'maxItems must be at least 1.',
        severity: ManifestDiagnosticSeverity.error,
      ),
    );
  } else if (cachedQuery.maxItems < 10) {
    diagnostics.add(
      _diagnostic(
        endpoint,
        method,
        'small_cache_max_items',
        'maxItems is very small and may evict useful data too aggressively.',
      ),
    );
  }

  if (cachedQuery.cacheVersion < 1) {
    diagnostics.add(
      _diagnostic(
        endpoint,
        method,
        'invalid_cache_version',
        'cacheVersion must be at least 1.',
        severity: ManifestDiagnosticSeverity.error,
      ),
    );
  }

  return diagnostics;
}

List<ManifestDiagnostic> _validateMutation(
  String endpoint,
  MethodManifestEntry method,
  MutationCommandMeta mutation,
) {
  final diagnostics = <ManifestDiagnostic>[];

  if (mutation.retry != 'RetryPolicy.none' && !mutation.idempotent) {
    diagnostics.add(
      _diagnostic(
        endpoint,
        method,
        'retry_requires_idempotent',
        'Automatic retry should only be enabled when idempotent is true.',
      ),
    );
  }

  if (mutation.idempotencyKeyArg != null && !mutation.idempotent) {
    diagnostics.add(
      _diagnostic(
        endpoint,
        method,
        'idempotency_key_without_idempotent',
        'idempotencyKeyArg is ignored unless idempotent is true.',
      ),
    );
  }

  if (mutation.retry != 'RetryPolicy.none' &&
      mutation.idempotent &&
      mutation.idempotencyKeyArg == null &&
      _looksLikeCreateMutationName(method.name)) {
    diagnostics.add(
      _diagnostic(
        endpoint,
        method,
        'create_retry_requires_idempotency_key',
        'Create-like mutations with retry enabled should declare idempotencyKeyArg to avoid duplicate creates after connection loss.',
      ),
    );
  }

  final returnType = _unwrapFuture(method.returnType);
  if (returnType == 'bool' &&
      mutation.refetch == 'RefetchPolicy.byId' &&
      mutation.byIdMethod == null) {
    diagnostics.add(
      _diagnostic(
        endpoint,
        method,
        'bool_mutation_requires_by_id',
        'Bool-returning mutations need byIdMethod when refetch is byId.',
      ),
    );
  }

  return diagnostics;
}

ManifestDiagnostic _diagnostic(
  String endpoint,
  MethodManifestEntry method,
  String code,
  String message, {
  ManifestDiagnosticSeverity severity = ManifestDiagnosticSeverity.warning,
}) {
  return ManifestDiagnostic(
    severity: severity,
    endpoint: endpoint,
    method: method.name,
    code: code,
    message: message,
  );
}

String _unwrapFuture(String raw) {
  final trimmed = raw.trim();
  return trimmed.startsWith('Future<') && trimmed.endsWith('>')
      ? trimmed.substring(7, trimmed.length - 1)
      : trimmed;
}

bool _isSupportedCachedReturnType(String returnType) {
  final trimmed = returnType.trim();
  if (trimmed.startsWith('List<') && trimmed.endsWith('>')) return true;
  if (trimmed.startsWith('Map<')) return false;
  if (trimmed.startsWith('Page<')) return false;
  if (trimmed.contains('<') && !trimmed.startsWith('List<')) return false;
  return true;
}

bool _looksLikeMutationName(String methodName) {
  final normalized = methodName.trim();
  if (normalized.isEmpty) return false;

  const prefixes = [
    'add',
    'archive',
    'assign',
    'change',
    'create',
    'delete',
    'insert',
    'patch',
    'publish',
    'remove',
    'restore',
    'save',
    'set',
    'submit',
    'unarchive',
    'update',
    'upsert',
  ];

  return prefixes.any((prefix) => normalized.startsWith(prefix));
}

bool _looksLikeCreateMutationName(String methodName) {
  final normalized = methodName.trim();
  if (normalized.isEmpty) return false;

  const prefixes = [
    'add',
    'create',
    'insert',
    'submit',
  ];

  return prefixes.any((prefix) => normalized.startsWith(prefix));
}
