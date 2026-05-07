import 'package:meta/meta.dart';

enum CacheMergePolicy {
  refetchById,
  replaceEntity,
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

@immutable
class CachedQuery {
  final Type entity;
  final String idField;
  final int maxItems;
  final Duration ttl;
  final bool secure;
  final String? byIdMethod;
  final CacheMergePolicy mergePolicy;
  final int cacheVersion;
  final bool backgroundRefresh;

  const CachedQuery({
    required this.entity,
    this.idField = 'id',
    this.maxItems = 1000,
    this.ttl = const Duration(minutes: 3),
    this.secure = false,
    this.byIdMethod,
    this.mergePolicy = CacheMergePolicy.refetchById,
    this.cacheVersion = 1,
    this.backgroundRefresh = true,
  });
}

@immutable
class MutationCommand {
  final Type affects;
  final String? idArg;
  final String idField;
  final String? byIdMethod;
  final List<Invalidate> invalidate;
  final OptimisticPolicy optimistic;
  final RetryPolicy retry;
  final RefetchPolicy refetch;
  final bool idempotent;
  final String? idempotencyKeyArg;
  final DialogPolicy closeDialog;

  const MutationCommand({
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

@immutable
class Invalidate {
  final String provider;
  final String? argFrom;
  final bool family;

  const Invalidate.all(this.provider)
      : argFrom = null,
        family = false;

  const Invalidate.family(this.provider, {required this.argFrom})
      : family = true;
}

@immutable
class ValidateString {
  final String arg;
  final bool notEmpty;
  final int? minLength;
  final int? maxLength;
  final String? pattern;

  const ValidateString({
    required this.arg,
    this.notEmpty = false,
    this.minLength,
    this.maxLength,
    this.pattern,
  });
}

@immutable
class ValidateNumber {
  final String arg;
  final num? min;
  final num? max;

  const ValidateNumber({
    required this.arg,
    this.min,
    this.max,
  });
}

@immutable
class ValidateList {
  final String arg;
  final bool notEmpty;
  final int? minLength;
  final int? maxLength;

  const ValidateList({
    required this.arg,
    this.notEmpty = false,
    this.minLength,
    this.maxLength,
  });
}

@immutable
class CacheTtl {
  final Duration value;

  const CacheTtl([this.value = const Duration(minutes: 3)]);
}

@immutable
class Timeout {
  final Duration value;

  const Timeout([this.value = const Duration(seconds: 30)]);
}

@immutable
class RefInvalidate {
  final List<String> endpoints;
  final bool includeSelf;

  const RefInvalidate(this.endpoints, {this.includeSelf = true});
}

@immutable
class DoNotGenerate {
  const DoNotGenerate();
}
