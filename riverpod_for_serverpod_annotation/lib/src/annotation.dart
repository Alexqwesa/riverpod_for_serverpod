import 'package:meta/meta.dart';

/// How mutations refresh **single cached entities** (`T` / `T?`) for this type’s
/// `GeneratedEntityCache`, together with [MutationCommand.refetch].
///
/// Stored on the per-entity template from the **first** [CachedQuery] for `entity`,
/// and repeated on **generatedEndpointManifest**.
///
/// ## What “merge” does **not** mean
///
/// Generated code calls `GeneratedEntityCache.putOne` (runtime package), passing the RPC
/// value serialized with **`toJson()`**. That **replaces the entire stored JSON** for that
/// entity id. Nothing compares the previous cache row to decide **which fields to keep**
/// or **overwrite**. There is **no** client-side field-by-field merge, patch delta, or
/// selective preservation of unstale columns.
///
/// So [mergeReturnedEntity] is **not** a fine-grained field merge today—it only names the
/// intent “take the mutation response as the next cache truth,” same as [replaceEntity]
/// in emitted Dart.
///
/// ## Choosing a policy
///
/// | Policy | Meaning in generated mutation helpers |
/// |--------|---------------------------------------|
/// | [replaceEntity] | **Default.** After success, when the RPC returns `T`/`T?` matching `entity`, write **`putOne(result)`**—full snapshot from the response (typical **send args + return same row type** APIs). |
/// | [refetchById] | Ignore **`result`** for the cache write when possible; **`byIdMethod`** + **`idArg`** load a fresh row, then **`putOne`** that (extra round-trip). |
/// | [mergeReturnedEntity] | **Same codegen as [replaceEntity]** right now. Optional if you like the name aligned with [RefetchPolicy.mergeReturnedEntity]; safe to ignore unless you want that symmetry in the manifest. |
///
/// Only valid on endpoint methods annotated with [CachedQuery] (`Session` first).
enum CacheMergePolicy {
  /// Reload row via `byIdMethod` + `idArg`, then **`putOne`**—the mutation **`result`**
  /// is **not** used for the cache write even when types match.
  refetchById,

  /// **Default**—when the mutation returns `T`/`T?` matching [CachedQuery.entity], replace
  /// the cached row with **`putOne(result)`** (whole JSON from **`toJson()`**).
  ///
  /// Use this for the usual case: arguments identify the row and the response is the
  /// full updated model of the **same** cached type.
  replaceEntity,

  /// Historical / naming alias: **identical generated behavior to [replaceEntity]**.
  ///
  /// There is **no** implementation that merges only some fields into an existing cache
  /// row—see enum docs above. Prefer **[replaceEntity]** for new code unless you want the
  /// manifest to say `mergeReturnedEntity` next to [RefetchPolicy.mergeReturnedEntity].
  mergeReturnedEntity,
}

/// Whether a mutation command should optimistically update local entity cache
/// entries before the server responds.
///
/// Use as [MutationCommand.optimistic]. The generator **does** branch on this:
/// [patchLocalCache] enables the optimistic patch path in generated mutation
/// command code.
///
/// Only valid on endpoint **methods** annotated with [MutationCommand] (first
/// parameter `Session session`).
enum OptimisticPolicy {
  /// No optimistic updates; the generated command waits on the server result.
  none,

  /// Patch the bound entity cache using returned data where applicable.
  ///
  /// **Codegen-visible**: affects emitted mutation command logic.
  patchLocalCache,
}

/// When generated mutation commands may automatically retry after transient
/// failures.
///
/// Use as [MutationCommand.retry]. Retry interacts with [MutationCommand.idempotent]
/// and [MutationCommand.idempotencyKeyArg]: non-idempotent retries risk
/// duplicate side effects (the generator warns when “create-like” names retry
/// without an idempotency key). Successful replays may register with
/// `MutationRetryReplayRegistry` from `riverpod_for_serverpod_runtime` for
/// diagnostics.
///
/// Only valid on endpoint **methods** annotated with [MutationCommand].
enum RetryPolicy {
  /// Do not retry automatically.
  none,

  /// Retry only for connection-oriented failures (not arbitrary errors).
  ///
  /// **Codegen-visible**: affects retry wrapping in generated mutation paths.
  connectionOnly,
}

/// What to do with entity/list providers after a mutation succeeds.
///
/// Use as [MutationCommand.refetch]. The generator emits logic that follows
/// this policy when refreshing caches; pairing with [MutationCommand.idArg],
/// [MutationCommand.idField], and [MutationCommand.byIdMethod] must be
/// consistent—invalid combinations are diagnosed at build time.
///
/// Only valid on endpoint **methods** annotated with [MutationCommand].
enum RefetchPolicy {
  /// Do not refetch related cached reads after success beyond explicit
  /// invalidations.
  none,

  /// Refetch the affected entity using `byIdMethod` and `idArg` /
  /// `idField`.
  byId,

  /// Prefer refreshing entity cache from the mutation **`result`** when types align,
  /// instead of only invalidating list providers.
  ///
  /// **Not field-level merge:** generated helpers call `GeneratedEntityCache.putOne`,
  /// which **replaces the whole cached JSON** from **`result.toJson()`**—see
  /// [CacheMergePolicy]. Pick [RefetchPolicy.byId] when you always want a separate load.
  mergeReturnedEntity,
}

/// Hint for UI layers about closing dialogs or sheets after a mutation.
///
/// Use as [MutationCommand.closeDialog]. Recorded in **generatedEndpointManifest**
/// and also exposed per command as
/// `Ref…Commands.dialogPolicyAfter<MethodName>` (a `static const DialogPolicy`)
/// so Flutter code can branch without parsing the manifest. The generator does
/// **not** call `Navigator.pop` or similar—UI remains responsible for navigation.
///
/// Only valid on endpoint **methods** annotated with [MutationCommand].
enum DialogPolicy {
  /// Do not treat success as an automatic close signal from generated code alone.
  never,

  /// Typical default: UI may close a dialog after confirming success.
  onSuccessOnly,
}

/// Marks an endpoint read as a cached Riverpod query backed by
/// `riverpod_for_serverpod_runtime` entity storage.
///
/// **Where:** only on Serverpod endpoint **methods** whose first parameter is
/// `Session session`, returning a `Future` (typically lists or entity rows).
///
/// **Codegen:** drives cache keys, TTL/`cacheFor`, optional secure storage,
/// `GeneratedEntityCache` wiring, and whether the provider uses stale-while-
/// revalidate ([backgroundRefresh]) vs a plain `FutureProvider`. [mergePolicy]
/// is folded into the per-entity cache template and affects how **mutations**
/// whose [MutationCommand.affects] matches this entity refresh local rows after success,
/// together with [MutationCommand.refetch]; see [CacheMergePolicy].
///
/// [byIdMethod] and related fields are validated by the generator and appear in
/// the manifest.
///
/// ```dart
/// @CachedQuery(entity: User, idField: 'id')
/// Future<List<User>> listUsers(Session session) async { ... }
/// ```
///
/// Family reads pass business arguments after `session`; `provider` names used
/// in [Invalidate] must match this **method name** (e.g. `listChildren`):
///
/// ```dart
/// @CachedQuery(entity: Child, idField: 'id')
/// Future<List<Child>> listChildren(Session session, String parentId) async {
///   ...
/// }
/// ```
@immutable
class CachedQuery {
  /// Dart type of rows stored in the generated entity cache (must match
  /// protocol / model types used in the method return type).
  final Type entity;

  /// Name of the id field on [entity] used for cache keys and merge helpers.
  ///
  /// Defaults to `'id'`.
  final String idField;

  /// Soft cap on how many distinct entities this cache tracks before eviction.
  final int maxItems;

  /// Duration passed to generated `cacheFor` after a successful fetch.
  final Duration ttl;

  /// When true, generated storage uses the secure cache flavor from runtime
  /// (e.g. sensitive rows).
  final bool secure;

  /// Optional endpoint **method name** on the same class used to load a single
  /// entity by id (for refetch / merge flows). Must match a real method name if
  /// set.
  ///
  /// Also recorded in the manifest; pairing with refetch policies is validated
  /// by the generator.
  final String? byIdMethod;

  /// Defaults to [CacheMergePolicy.replaceEntity]: treat a matching **`Future<T>` /
  /// `Future<T?>`** mutation response as the **full** next cache snapshot (`putOne`).
  final CacheMergePolicy mergePolicy;

  /// Bumps cache namespace when you make breaking changes to cached shape or
  /// semantics so stale hive/storage entries are not reused blindly.
  final int cacheVersion;

  /// When true (default), generated provider uses async notifier-style stale-
  /// while-revalidate when supported; when false, behaves closer to a one-shot
  /// auto-dispose `FutureProvider` without background refresh.
  final bool backgroundRefresh;

  const CachedQuery({
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

/// Marks an endpoint method as a **mutation**: generates a typed mutation
/// command (and controller hooks) instead of a watched read provider, plus
/// optional cache writes and invalidations.
///
/// **Where:** only on Serverpod endpoint **methods** whose first parameter is
/// `Session session`.
///
/// **Codegen:** drives invalidation lists, optimistic updates, retry/refetch,
/// idempotency wiring, validation around the client call, and a per-method
/// `dialogPolicyAfter…` constant for [closeDialog] (see [DialogPolicy]). The
/// manifest still carries [closeDialog] for introspection.
///
/// ```dart
/// @MutationCommand(
///   affects: User,
///   invalidate: [Invalidate.all('listUsers')],
///   idArg: 'userId',
/// )
/// Future<User?> updateUser(Session session, int userId, String name) async {
///   ...
/// }
/// ```
@immutable
class MutationCommand {
  /// Entity type used for generated cache templates and merge/refetch wiring.
  final Type affects;

  /// Method parameter name holding the primary entity id (must match the Dart
  /// parameter name exactly).
  ///
  /// Used with [byIdMethod], [idField], and [refetch] for targeted refresh.
  final String? idArg;

  /// Field name on [affects] treated as the primary key (`'id'` by default).
  final String idField;

  /// Same meaning as [CachedQuery.byIdMethod]: method name to load one row by
  /// id when refetching.
  final String? byIdMethod;

  /// Cached query providers to invalidate when this mutation succeeds.
  ///
  /// Each [Invalidate.provider] must be the **generated provider field name**,
  /// which equals the **endpoint method name** (e.g. `listParents`, not a type
  /// or class name).
  final List<Invalidate> invalidate;

  /// Whether to patch local entity cache optimistically.
  final OptimisticPolicy optimistic;

  /// Automatic retry behavior for transient failures.
  ///
  /// Prefer [RetryPolicy.none] or supply [idempotencyKeyArg] when retries could
  /// duplicate creates.
  final RetryPolicy retry;

  /// How entity/list caches refresh after a successful mutation.
  final RefetchPolicy refetch;

  /// Declare mutations safe to replay (e.g. PUT-style updates). When false,
  /// aggressive retries can duplicate side effects—see generator diagnostics.
  final bool idempotent;

  /// Parameter name whose value is treated as an idempotency key for retries
  /// (must match a real parameter). Helps safe deduplication for creates.
  final String? idempotencyKeyArg;

  /// Hint for when UI may close a dialog after success; also exposed as
  /// `dialogPolicyAfter<MethodName>` on generated `Ref…Commands`. Does not call
  /// navigation APIs from generated code.
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

/// Names one cached query provider to invalidate after a mutation succeeds.
///
/// Use inside [MutationCommand.invalidate]. [provider] must equal the target
/// endpoint **method name** (the generated static provider field), not a class
/// name.
///
/// For [Invalidate.family], [argFrom] must name a parameter on the **mutation**
/// method; its runtime value is passed as the family argument when invalidating
/// the target family provider.
///
/// ```dart
/// Invalidate.all('listUsers')
/// Invalidate.family('listChildren', argFrom: 'parentId')
/// ```
@immutable
class Invalidate {
  /// Target method name string (matches generated provider identifier).
  final String provider;

  /// Mutation parameter name supplying the family argument for family
  /// providers.
  final String? argFrom;

  /// True when invalidating a `.family` provider.
  final bool family;

  const Invalidate.all(this.provider)
      : argFrom = null,
        family = false;

  const Invalidate.family(this.provider, {required this.argFrom})
      : family = true;
}

/// Client-side string validation run **before** the generated mutation command
/// invokes the Serverpod client.
///
/// **Where:** place one or more `@ValidateString(...)` annotations on the same
/// endpoint **method** as [MutationCommand] (first parameter `Session session`).
/// Does **not** replace server-side validation.
///
/// [arg] must exactly match a Dart parameter name on that method. The generator
/// emits calls to `validateGenerated*` helpers from
/// `riverpod_for_serverpod_runtime`; failed checks throw at the call site on
/// the client.
@immutable
class ValidateString {
  /// Parameter name to validate (must match the method parameter).
  final String arg;

  /// Require non-empty after trim.
  final bool notEmpty;

  /// Minimum UTF-8 length (inclusive).
  final int? minLength;

  /// Maximum UTF-8 length (inclusive).
  final int? maxLength;

  /// Optional regular expression pattern string passed to generated validation.
  final String? pattern;

  const ValidateString({
    required this.arg,
    this.notEmpty = false,
    this.minLength,
    this.maxLength,
    this.pattern,
  });
}

/// Client-side numeric validation before the mutation client call.
///
/// Same placement as [ValidateString]: annotate the [MutationCommand] method
/// with `@ValidateNumber(...)`. [arg] must match a real parameter name. Emitted
/// checks use `riverpod_for_serverpod_runtime` helpers; they do not replace
/// server validation.
@immutable
class ValidateNumber {
  /// Parameter name to validate (must match the method parameter).
  final String arg;

  /// Minimum allowed value (inclusive).
  final num? min;

  /// Maximum allowed value (inclusive).
  final num? max;

  const ValidateNumber({
    required this.arg,
    this.min,
    this.max,
  });
}

/// Client-side list validation before the mutation client call.
///
/// Same placement as [ValidateString]: annotate the [MutationCommand] method;
/// [arg] names the list parameter exactly.
@immutable
class ValidateList {
  /// Parameter name to validate (must match the method parameter).
  final String arg;

  /// Require at least one element.
  final bool notEmpty;

  /// Minimum length (inclusive).
  final int? minLength;

  /// Maximum length (inclusive).
  final int? maxLength;

  const ValidateList({
    required this.arg,
    this.notEmpty = false,
    this.minLength,
    this.maxLength,
  });
}

/// Overrides default `cacheFor` duration on a generated read provider.
///
/// **Where:** Serverpod endpoint **methods** whose first parameter is
/// `Session session`. Changes how long Riverpod keeps a successful response
/// alive after the fetch completes.
@immutable
class CacheTtl {
  /// TTL applied via generated `ref.cacheFor(value)`.
  final Duration value;

  const CacheTtl([this.value = const Duration(minutes: 3)]);
}

/// Overrides default timeout wrapping on generated endpoint calls.
///
/// **Where:** Serverpod endpoint **methods** with `Session` first. The
/// generator applies `.timeout(value)` (or equivalent) around the client
/// invocation as emitted.
@immutable
class Timeout {
  /// Timeout duration for the generated Future.
  final Duration value;

  const Timeout([this.value = const Duration(seconds: 30)]);
}

/// After this mutation succeeds, refresh generated providers for other
/// endpoints (and optionally the current one).
///
/// **Where:** Serverpod endpoint **methods** whose first parameter is
/// `Session session`.
///
/// **Codegen:** emits hooks so `Ref<TargetEndpoint>.updateAll(read)` runs after
/// success. Each entry in [endpoints] may be written as a short class stem like
/// `'UserEndpoint'` or already prefixed `'RefUserEndpoint'`; the generator
/// normalizes to `Ref`-prefixed names.
///
/// When [includeSelf] is false, the hook skips refreshing the current endpoint’s
/// generated `Ref` class (only [endpoints] and other configured targets run).
///
/// ```dart
/// @RefInvalidate(['UserEndpoint'])
/// Future<void> updateRole(Session session, int userId, String role) async {
///   ...
/// }
/// ```
@immutable
class RefInvalidate {
  /// Endpoint class names (`'BankEndpoint'`) or `Ref...` names to refresh.
  final List<String> endpoints;

  /// When false, generated invalidation does not include this endpoint’s own
  /// `updateAll`.
  final bool includeSelf;

  const RefInvalidate(this.endpoints, {this.includeSelf = true});
}

/// Skips code generation for an endpoint class or a single method.
///
/// **Where:** place on a Serverpod `Endpoint` subclass to omit the whole class,
/// or on individual methods to omit just those units (no provider / manifest
/// entries for skipped items).
///
/// Use when a method would otherwise warn as mutation-like or when you handle
/// Riverpod wiring manually.
@immutable
class DoNotGenerate {
  const DoNotGenerate();
}
