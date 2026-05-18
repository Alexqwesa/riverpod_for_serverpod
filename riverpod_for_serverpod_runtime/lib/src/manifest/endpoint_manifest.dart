/// Policy for how mutations refresh cached entities (mirrors the annotation
/// package `CacheMergePolicy`).
enum CacheMergePolicy {
  /// Reload via `byId` before caching (mutation response ignored for cache write).
  refetchById,

  /// Default—full snapshot from mutation response (`putOne(result)`).
  replaceEntity,

  /// Same codegen as `replaceEntity` today (no field-level merge in runtime).
  mergeReturnedEntity,
}

enum OptimisticPolicy {
  none,
  patchLocalCache,
}

enum RetryPolicy {
  none,
  connectionOnly,
}

enum RefetchPolicy {
  none,
  byId,
  mergeReturnedEntity,
}

enum DialogPolicy {
  never,
  onSuccessOnly,
}

class EndpointManifest {
  final List<EndpointInfo> endpoints;

  const EndpointManifest({
    required this.endpoints,
  });

  EndpointInfo? endpointByName(String name) {
    for (final endpoint in endpoints) {
      if (endpoint.name == name) {
        return endpoint;
      }
    }

    return null;
  }
}

class EndpointInfo {
  final String name;
  final List<MethodInfo> methods;

  const EndpointInfo({
    required this.name,
    required this.methods,
  });

  MethodInfo? methodByName(String name) {
    for (final method in methods) {
      if (method.name == name) {
        return method;
      }
    }

    return null;
  }
}

class MethodInfo {
  final String name;
  final String returnType;
  final List<ParamInfo> positionalParams;
  final List<ParamInfo> namedParams;
  final CachedQueryInfo? cachedQuery;
  final MutationCommandInfo? mutationCommand;
  final List<ValidateStringInfo> validateStrings;
  final List<ValidateNumberInfo> validateNumbers;
  final List<ValidateListInfo> validateLists;

  const MethodInfo({
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

  ParamInfo? paramByName(String name) {
    for (final param in [...positionalParams, ...namedParams]) {
      if (param.name == name) {
        return param;
      }
    }

    return null;
  }
}

class ParamInfo {
  final String name;
  final String type;
  final String? defaultValue;

  const ParamInfo({
    required this.name,
    required this.type,
    this.defaultValue,
  });
}

class CachedQueryInfo {
  final String entity;
  final String idField;
  final int maxItems;
  final Duration ttl;
  final bool secure;
  final String? byIdMethod;
  final CacheMergePolicy mergePolicy;
  final int cacheVersion;
  final bool backgroundRefresh;

  const CachedQueryInfo({
    required this.entity,
    this.idField = 'id',
    this.maxItems = 1000,
    this.ttl = const Duration(minutes: 3),
    this.secure = false,
    this.byIdMethod,
    this.mergePolicy = CacheMergePolicy.replaceEntity,
    this.cacheVersion = 1,
    this.backgroundRefresh = true,
  });
}

class MutationCommandInfo {
  final String affects;
  final String? idArg;
  final String idField;
  final String? byIdMethod;
  final List<InvalidateInfo> invalidate;
  final OptimisticPolicy optimistic;
  final RetryPolicy retry;
  final RefetchPolicy refetch;
  final bool idempotent;
  final String? idempotencyKeyArg;
  final DialogPolicy closeDialog;

  const MutationCommandInfo({
    required this.affects,
    this.idArg,
    this.idField = 'id',
    this.byIdMethod,
    this.invalidate = const [],
    this.optimistic = OptimisticPolicy.none,
    this.retry = RetryPolicy.connectionOnly,
    this.refetch = RefetchPolicy.byId,
    this.idempotent = false,
    this.idempotencyKeyArg,
    this.closeDialog = DialogPolicy.onSuccessOnly,
  });
}

class InvalidateInfo {
  final String provider;
  final String? argFrom;
  final bool family;

  const InvalidateInfo({
    required this.provider,
    this.argFrom,
    required this.family,
  });

  const InvalidateInfo.all(this.provider)
      : argFrom = null,
        family = false;

  const InvalidateInfo.family(this.provider, {required this.argFrom})
      : family = true;
}

class ValidateStringInfo {
  final String arg;
  final bool notEmpty;
  final int? minLength;
  final int? maxLength;
  final String? pattern;

  const ValidateStringInfo({
    required this.arg,
    this.notEmpty = false,
    this.minLength,
    this.maxLength,
    this.pattern,
  });
}

class ValidateNumberInfo {
  final String arg;
  final num? min;
  final num? max;

  const ValidateNumberInfo({
    required this.arg,
    this.min,
    this.max,
  });
}

class ValidateListInfo {
  final String arg;
  final bool notEmpty;
  final int? minLength;
  final int? maxLength;

  const ValidateListInfo({
    required this.arg,
    this.notEmpty = false,
    this.minLength,
    this.maxLength,
  });
}
