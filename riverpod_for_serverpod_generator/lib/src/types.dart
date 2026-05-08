// file: tool/codegen/meta.dart

class ParamInfo {
  final String recordType;
  final String destructuredVars;
  final String methodCall;

  const ParamInfo(this.recordType, this.destructuredVars, this.methodCall);

  // factory ParamInfo.fromNamedParams(List<MyParamMeta> params, {String recordVar = 'args'}) {
  //   final recordType = '({${params.map((p) => '${p.type} ${p.name}').join(', ')}})';
  //   final destructured =
  //       'final $recordType(${params.map((p) => ':${p.name}').join(', ')}) = $recordVar;';
  //   final call = '(${params.map((p) => '${p.name}: ${p.name}').join(', ')})';
  //   return ParamInfo(recordType, destructured, call);
  // }
}

/// Constructor and argument wiring for generated [@CachedQuery] SWR [AsyncNotifier]s.
class SwrNotifierHostParams {
  final String instanceFields;
  final String constructorParams;
  final String buildParamPrelude;
  final String rpcArgs;

  const SwrNotifierHostParams({
    required this.instanceFields,
    required this.constructorParams,
    required this.buildParamPrelude,
    required this.rpcArgs,
  });
}

class CachedQueryMeta {
  final String entity;
  final String idField;
  final int maxItems;
  final String ttl;
  final bool secure;
  final String? byIdMethod;
  final String mergePolicy;
  final int cacheVersion;
  final bool backgroundRefresh;

  const CachedQueryMeta({
    required this.entity,
    this.idField = 'id',
    this.maxItems = 1000,
    this.ttl = 'Duration(minutes: 3)',
    this.secure = false,
    this.byIdMethod,
    this.mergePolicy = 'CacheMergePolicy.refetchById',
    this.cacheVersion = 1,
    this.backgroundRefresh = true,
  });
}

class MutationCommandMeta {
  final String affects;
  final String? idArg;
  final String idField;
  final String? byIdMethod;
  final List<InvalidateMeta> invalidate;
  final String optimistic;
  final String retry;
  final String refetch;
  final bool idempotent;
  final String? idempotencyKeyArg;
  final String closeDialog;

  const MutationCommandMeta({
    required this.affects,
    this.idArg,
    this.idField = 'id',
    this.byIdMethod,
    this.invalidate = const [],
    this.optimistic = 'OptimisticPolicy.none',
    this.retry = 'RetryPolicy.connectionOnly',
    this.refetch = 'RefetchPolicy.byId',
    this.idempotent = false,
    this.idempotencyKeyArg,
    this.closeDialog = 'DialogPolicy.onSuccessOnly',
  });
}

class InvalidateMeta {
  final String provider;
  final String? argFrom;
  final bool family;

  const InvalidateMeta.all(this.provider)
      : argFrom = null,
        family = false;

  const InvalidateMeta.family(this.provider, {required this.argFrom})
      : family = true;
}

class ValidateStringMeta {
  final String arg;
  final bool notEmpty;
  final int? minLength;
  final int? maxLength;
  final String? pattern;

  const ValidateStringMeta({
    required this.arg,
    this.notEmpty = false,
    this.minLength,
    this.maxLength,
    this.pattern,
  });
}

class ValidateNumberMeta {
  final String arg;
  final num? min;
  final num? max;

  const ValidateNumberMeta({
    required this.arg,
    this.min,
    this.max,
  });
}

class ValidateListMeta {
  final String arg;
  final bool notEmpty;
  final int? minLength;
  final int? maxLength;

  const ValidateListMeta({
    required this.arg,
    this.notEmpty = false,
    this.minLength,
    this.maxLength,
  });
}

class EndpointManifestMeta {
  final List<EndpointManifestEntry> endpoints;

  const EndpointManifestMeta(this.endpoints);
}

class EndpointManifestEntry {
  final String name;
  final List<MethodManifestEntry> methods;

  const EndpointManifestEntry({
    required this.name,
    required this.methods,
  });
}

class MethodManifestEntry {
  final String name;
  final String returnType;
  final List<MyParamMeta> positionalParams;
  final List<MyParamMeta> namedParams;
  final CachedQueryMeta? cachedQuery;
  final MutationCommandMeta? mutationCommand;
  final List<ValidateStringMeta> validateStrings;
  final List<ValidateNumberMeta> validateNumbers;
  final List<ValidateListMeta> validateLists;

  const MethodManifestEntry({
    required this.name,
    required this.returnType,
    required this.positionalParams,
    required this.namedParams,
    this.cachedQuery,
    this.mutationCommand,
    this.validateStrings = const [],
    this.validateNumbers = const [],
    this.validateLists = const [],
  });
}

class MyParamMeta {
  final String name;
  final String type; // e.g. 'int?', 'bool', 'String?'
  final String? defaultValue; // raw default literal text from code, or null

  const MyParamMeta(this.name, this.type, this.defaultValue);

  bool get isNullable => type.trim().endsWith('?');

  bool get hasDefault => defaultValue != null;

  /// Returns the default literal as code, or null if none exists in source.
  String? get defaultCodeOrNull => defaultValue;

  /// Param is "defaultable": either nullable or has a default literal.
  bool get isDefaultable => isNullable || hasDefault;
}

class MyMethodMeta {
  final String name;
  final String returnType; // may be 'Future<T>'
  final List<MyParamMeta> positionalParams;
  final List<MyParamMeta> namedParams;
  final bool hasPositionalParams;
  final bool hasNamedParams;
  final String cacheTtl;
  // Nullable: non-null means generate .timeout(const Duration(...)) on the call.
  final String? timeout;
  final List<String> invalidateTargets;
  final bool includeSelfInHook;

  // computed by constructor
  late final String recordArgType; // e.g. '({int? a, bool b})' or '()'
  late final String unwrappedReturnType; // e.g. 'List<WorkType>'

  /// Name of generated inner provider, e.g. 'RefWorkTypeEndpoint.filtered'
  final String innerProviderName;

  final CachedQueryMeta? cachedQuery;
  final MutationCommandMeta? mutationCommand;

  final List<ValidateStringMeta> validateStrings;
  final List<ValidateNumberMeta> validateNumbers;
  final List<ValidateListMeta> validateLists;

  MyMethodMeta(
    this.name,
    this.returnType,
    this.positionalParams,
    this.namedParams,
    this.hasPositionalParams,
    this.hasNamedParams, {
    this.cacheTtl = 'Duration(minutes: 3)',
    this.innerProviderName = 'refERROR',
    this.timeout,
    this.invalidateTargets = const [],
    this.includeSelfInHook = true,
    this.cachedQuery,
    this.mutationCommand,
    this.validateStrings = const [],
    this.validateNumbers = const [],
    this.validateLists = const [],
  }) {
    unwrappedReturnType = _unwrapFuture(returnType);
    recordArgType = _buildRecordArgType(namedParams);
  }

  /// Named params that can be defaulted/omitted safely.
  List<MyParamMeta> get defaultableNamed =>
      namedParams.where((p) => p.isDefaultable).toList();

  /// True if there exists a required, non-defaultable named param.
  bool get hasRequiredNamedWithoutDefault =>
      namedParams.any((p) => !p.isDefaultable);

  /// Build record type for the **first i** defaultable named params.
  String recordArgTypeForFirstN(int i) {
    final sub = defaultableNamed.take(i).toList();
    return _buildRecordArgType(sub);
  }

  /// Forward all named from a record var (used by the main provider).
  String callArgsFrom(String varName) {
    if (namedParams.isEmpty) return '()';
    final parts = <String>[];
    for (final p in namedParams) {
      parts.add('${p.name}: $varName.${p.name}');
    }
    return '(${parts.join(', ')})';
  }

  /// For VARIANT i:
  ///  - include first i defaultables from arg
  ///  - include remaining defaultables *only if* they have a default literal
  ///  - omit non-defaultable named params entirely (never fabricate values)
  String callArgsForVariantFrom(String argVar, int i) {
    final parts = <String>[];

    final firstI = defaultableNamed.take(i).toList();
    final rest = defaultableNamed.skip(i).toList();

    // 1) First i from arg
    for (final p in firstI) {
      parts.add('${p.name}: $argVar.${p.name}');
    }
    // 2) Remaining defaultables -> only if code default exists; else omit
    for (final p in rest) {
      final def = p.defaultCodeOrNull;
      if (def != null) {
        parts.add('${p.name}: $def');
      }
    }
    // 3) Non-defaultable named params -> OMIT (caller must use the main provider)

    return '(${parts.join(', ')})';
  }

  /// Whether variant i is safe to emit:
  ///  - allowed even if there are required-named params, because we *omit* them;
  ///    however, consumer code must not call the variant if their API requires them.
  /// If you want to be stricter, you can return false when there are required params.
  bool canBuildVariant(int i) => true;

  String innerProviderExprFrom(String recordVarName) =>
      '$innerProviderName(${callArgsFrom(recordVarName)})';

  // utils
  static String _unwrapFuture(String raw) {
    final t = raw.trim();
    return (t.startsWith('Future<') && t.endsWith('>'))
        ? t.substring(7, t.length - 1)
        : t;
  }

  static String _buildRecordArgType(List<MyParamMeta> params) {
    if (params.isEmpty) return '()';
    final fields = params.map((p) => '${p.type} ${p.name}').join(', ');
    return '({$fields})';
  }
}
