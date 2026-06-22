# Serverpod → Riverpod Controller Generator: Implementation Plan

## Current repository status

This plan describes the larger controller/offline-cache generator direction.
The current repository has completed a smaller Riverpod 3 foundation:

```text
DONE:
  annotation package exists
  future annotation API exists for @CachedQuery / @MutationCommand / validation metadata
  generator parser metadata exists for @CachedQuery / @MutationCommand / validation metadata
  internal endpoint manifest builder scans Serverpod source into query/mutation/validation metadata
  generatedEndpointManifest typed const object is emitted into generated Dart output
  strongly typed runtime manifest classes exist for @CachedQuery / @MutationCommand annotations
  manifest diagnostics warn about invalid or risky query/mutation annotation combinations
  runtime package exists with storage interface, memory storage, entity/index records, and entity cache
  JSON cache storage adapter exists over string key-value storage
  optional Hive storage adapter package exists for Box<String>
  secure/encrypted Hive setup helpers exist
  generator package exists
  build_runner builder scans Serverpod Endpoint classes
  methods are guarded by Future return type + Session first parameter
  generated Riverpod FutureProvider / FutureProvider.family wrappers
  generated TTL keepAlive cache via ref.cacheFor after successful calls
  generated timeout support
  generated endpoint and mutation-style invalidation hooks
  @DoNotGenerate skip support
  auto-apply builder for dependent packages
  copy_ref_endpoints helper
  README / controller generator design / riverpod_2_and_3_compatibility / MIT license / Riverpod 3 release-line notes
  Riverpod 3 provider auto-retry is explicitly disabled for generated endpoint providers
  generated command helpers run ValidateString / ValidateNumber / ValidateList before RPC (runtime helpers)
  generated @CachedQuery read providers use GeneratedEntityCache (readList on fresh index; putList after successful fetch; index key from provider id + json-encoded args; secure flag selects storage provider)
  @CachedQuery with backgroundRefresh (default true): autoDispose AsyncNotifier SWR — return fresh cache immediately, Future.microtask background revalidation, AsyncData refresh, refresh failures to refreshWarningProvider without failing the cached load
  @CachedQuery with backgroundRefresh: false keeps FutureProvider + inline cache read/put (no background microtask)
  generatedCacheStorageProvider / generatedSecureCacheStorageProvider runtime defaults exist and can be overridden by apps
  NamespacedGeneratedCacheStorage supports per-user cache isolation
  clearGeneratedCacheNamespace clears namespaced key-value cache records for logout
  generated mutation commands record queued retry warnings through refreshWarningProvider
  mutationRetryQueueProvider keeps queued warning count synchronized after schedule, retry, cancel, and clear
  generated AsyncNotifier<void> mutation controllers delegate to Ref<Endpoint>Commands and expose loading/error state
  manifest diagnostics warn when mutation-like method names lack @MutationCommand
  manifest diagnostics warn when create-like mutations enable retry without idempotencyKeyArg
  manifest diagnostics error when annotation argument references point to missing method parameters
  mutation commands: optimistic local cache (pendingSync + rollback on failure) and post-success entity cache updates (RefetchPolicy.mergeReturnedEntity / byId when entity cache template exists)
  idempotent mutation retry persistence: MutationRetryPersistedPayload on schedule, JSON snapshot in GeneratedKeyValueStorage, hydrate + MutationRetryReplayRegistry, generated op registrations, mutationRetryPersistenceStorageProvider
  manifest diagnostic when @CachedQuery uses secure: true (override generatedSecureCacheStorageProvider / encrypted storage)
  integration test: secure vs plain storage providers keep entity records isolated when overridden

NOT DONE YET (narrower follow-ups):
  full sample Flutter apps / long-form guides (Phase 9 style walkthroughs)
  static verification that CachedQuery idField matches protocol model fields
  field-level optimistic patches beyond pendingSync / server merge refetch

```

Current package names are still:

```text
riverpod_for_serverpod_annotation
riverpod_for_serverpod_generator
```

The future package names in this plan can be introduced during the larger
runtime/cache rewrite.

## 1. Goal

Build a generator that lets you write most data-access intent once on the Serverpod backend, add a small number of annotations, and get usable Flutter/Riverpod frontend code:

```text
Serverpod endpoint + annotations
  → generated endpoint manifest
  → generated cached query providers
  → generated mutation commands
  → generated cache invalidation
  → generated retry queue and warning aggregator
  → optional hand-written screen controller
```

The generator should not try to fully replace screen-specific UI logic. It should generate the boring, repeatable, and error-prone parts:

```text
read provider creation
argument mapping
local entity cache
list index cache
by-id cache
TTL behavior
offline fallback
mutation wrappers
optimistic cache patching
retry queue for connection errors
cache invalidation after mutation
global sync warning aggregation
secure cache routing
```

The user-facing screen code should still decide:

```text
which dialog to open
which dialog to close
which tab/filter is selected
how to lay out the data
which custom validation message to show
which workflow-specific conflict UI to show
```

This keeps generated code powerful but not dangerously magical.

---

## 2. Important assumptions

### 2.1 Serverpod is the source of truth

Serverpod endpoint methods are still the canonical API. The generated frontend code wraps the generated Serverpod client.

Example backend endpoint:

```dart
class AdminEndpoint extends Endpoint {
  Future<List<UserSummary>> listUsersByRole(
    Session session,
    String roleName,
  ) async {
    // Query DB and return typed Serverpod model.
  }
}
```

Serverpod generates a client call like:

```dart
client.admin.listUsersByRole(roleName)
```

The controller generator should not replace Serverpod's own client generation. It should sit above it.

### 2.2 Riverpod providers are frontend cache boundaries

Riverpod providers already cache their result while alive. For simple read endpoints, `FutureProvider.autoDispose + keepAlive TTL` is enough.

But for offline support, stale-while-revalidate, entity-level cache updates, retry queue, and pending-sync flags, we need a generated cache runtime.

### 2.3 Hive/Riverpod storage is persistent cache, not the source of truth

Hive or a Riverpod `Storage` adapter stores cached frontend data. It is not the authoritative database.

The source of truth remains:

```text
Serverpod server
  → PostgreSQL
```

Local cache is for:

```text
fast page open
slow connection fallback
showing old data while refresh fails
optimistic local updates
retrying safe connection failures
```

---

## 3. Package structure

Use separate packages to avoid mixing annotation definitions, generator code, and runtime code.

Recommended layout:

```text
packages/
  serverpod_riverpod_annotations/
    lib/serverpod_riverpod_annotations.dart

  serverpod_riverpod_runtime/
    lib/src/cache/generated_entity_cache.dart
    lib/src/cache/generated_cache_storage.dart
    lib/src/retry/retry_queue.dart
    lib/src/warnings/sync_warning_center.dart
    lib/src/errors/generated_error_mapper.dart
    lib/serverpod_riverpod_runtime.dart

  serverpod_riverpod_hive_storage/
    lib/src/hive_generated_cache_storage.dart
    lib/src/hive_secure_cache_storage.dart
    lib/serverpod_riverpod_hive_storage.dart

  serverpod_riverpod_generator/
    lib/src/manifest_builder.dart
    lib/src/query_provider_generator.dart
    lib/src/mutation_command_generator.dart
    lib/src/cache_provider_generator.dart
    lib/src/diagnostics.dart
    lib/serverpod_riverpod_generator.dart
```

Why separate packages?

```text
annotations package
  imported by backend endpoints and frontend build step
  must be very small
  should not depend on Flutter, Riverpod, Hive, or Serverpod runtime details

runtime package
  used by generated frontend code
  contains cache/retry/warning primitives

hive storage package
  optional storage implementation
  can be replaced later by SQLite or another backend

generator package
  build_runner/source_gen code
  should not be imported by app runtime
```

---

## 4. Core generated architecture

For a cached read endpoint:

```text
Generated AsyncNotifier provider
  → GeneratedEntityCache<T>
    → GeneratedCacheStorage
      → Hive / encrypted Hive / other storage
  → Serverpod client endpoint
```

For a mutation endpoint:

```text
Generated mutation command
  → optional client-side validation
  → optional optimistic cache patch
  → Serverpod client endpoint
  → success: merge result into entity cache
  → connection failure: queue retry + warning aggregator
  → domain/server validation failure: rollback optimistic patch + return error
  → invalidate related generated read providers
```

The generated code should never directly show a snackbar/dialog. It should report to a warning aggregator. UI decides how to display that warning.

---

## 5. Annotation API

### 5.1 `@CachedQuery`

Use this for read endpoints that should be cached.

```dart
class CachedQuery {
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

  final Type entity;
  final String idField;
  final int maxItems;
  final Duration ttl;
  final bool secure;
  final String? byIdMethod;
  final CacheMergePolicy mergePolicy;
  final int cacheVersion;
  final bool backgroundRefresh;
}
```

Example:

```dart
class AdminEndpoint extends Endpoint {
  @CachedQuery(
    entity: UserSummary,
    idField: 'id',
    maxItems: 1000,
    secure: true,
    byIdMethod: 'getUserSummaryById',
  )
  Future<List<UserSummary>> listUsersByRole(
    Session session,
    String roleName,
  ) async {
    // ...
  }

  @CachedQuery(
    entity: UserSummary,
    idField: 'id',
    secure: true,
  )
  Future<UserSummary?> getUserSummaryById(
    Session session,
    int userId,
  ) async {
    // ...
  }
}
```

Reason:

```text
The generator cannot always infer the entity type from return type alone.
List<UserSummary> is easy, but wrappers like Page<UserSummary> or ApiResult<List<UserSummary>> are not.
The annotation gives explicit cache intent.
```

### 5.2 `@MutationCommand`

Use this for methods that change state.

```dart
class MutationCommand {
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

  final Type affects;
  final String? idArg;
  final String idField;
  final String? byIdMethod;
  final List<Object> invalidate;
  final OptimisticPolicy optimistic;
  final RetryPolicy retry;
  final RefetchPolicy refetch;
  final bool idempotent;
  final String? idempotencyKeyArg;
  final DialogPolicy closeDialog;
}
```

Example:

```dart
class AdminEndpoint extends Endpoint {
  @MutationCommand(
    affects: UserSummary,
    idArg: 'userId',
    invalidate: [
      Invalidate.all('listUsersByRole'),
      Invalidate.all('listUsersByDepartment'),
      Invalidate.family('getUserSummaryById', argFrom: 'userId'),
    ],
    optimistic: OptimisticPolicy.patchLocalCache,
    retry: RetryPolicy.connectionOnly,
    refetch: RefetchPolicy.mergeReturnedEntity,
    idempotent: true,
  )
  Future<UserSummary> updateUserRole(
    Session session,
    int userId,
    String roleName,
  ) async {
    // Return the updated entity if possible.
  }
}
```

Reason:

```text
Read endpoints can be cached.
Mutation endpoints should not be represented as FutureProvider.
They are commands, not values.
They should run only when explicitly called by UI/controller code.
```

### 5.3 `@ValidateString`, `@ValidateNumber`, `@ValidateList`

Generate only simple input validation. Keep business validation on server.

Example:

```dart
@ValidateString(
  arg: 'roleName',
  notEmpty: true,
  maxLength: 50,
)
@MutationCommand(
  affects: UserSummary,
  idArg: 'userId',
)
Future<UserSummary> updateUserRole(
  Session session,
  int userId,
  String roleName,
) async {
  // Server still checks permissions and business rules.
}
```

Generated frontend check:

```dart
if (roleName.trim().isEmpty) {
  throw GeneratedValidationException(
    code: 'roleName_empty',
    message: aloc(
      'Role is required|Bắt buộc nhập vai trò|Роль обязательна',
    ),
  );
}
```

Good generated validation:

```text
required
not empty
min length
max length
numeric range
regex
list not empty
date from <= date to
file size limit
```

Do not generate these automatically:

```text
user has permission to approve
status transition is allowed
role exists in server table
department can use this role
workflow step is still active
record was not changed by another user
```

These belong on the server.

---

## 6. Query vs mutation classification

### 6.1 Explicit annotation wins

```text
@CachedQuery     → generate cached read provider
@MutationCommand → generate command/controller helper
```

### 6.2 Heuristics are warnings only

The generator may infer likely intent by method name, but it should not silently make risky decisions.

Likely query names:

```text
get*
list*
search*
find*
load*
fetch*
count*
```

Likely mutation names:

```text
create*
insert*
update*
delete*
remove*
set*
assign*
approve*
reject*
send*
run*
backup*
import*
clear*
```

Example diagnostic:

```text
WARNING: AdminEndpoint.updateUserRole looks like a mutation but has no @MutationCommand.
Generated as remote-only command with no cache patch and no retry.
```

Do not analyze method body for `.db.insert`, `.db.update`, or `.db.delete` as the primary decision source. Writes may happen inside services, helpers, transactions, or stored procedures.

---

## 7. Cache design

### 7.1 Do not store only endpoint result blobs

Bad cache:

```text
listUsersByRole('admin') → full JSON list of UserSummary
listUsersByDepartment(5) → full JSON list of UserSummary
```

This duplicates the same entity many times and makes mutation updates hard.

Better cache:

```text
entity/UserSummary/123 → UserSummary JSON
entity/UserSummary/124 → UserSummary JSON

index/AdminEndpoint.listUsersByRole/sha1({"roleName":"admin"}) → [123, 124]
index/AdminEndpoint.listUsersByDepartment/sha1({"departmentId":5}) → [123, 200, 240]
```

When one user is updated, update only:

```text
entity/UserSummary/123
```

All list indexes that contain `123` can then display the updated object.

### 7.2 Entity cache entry

```dart
class CachedEntityRecord {
  const CachedEntityRecord({
    required this.entityName,
    required this.id,
    required this.json,
    required this.updatedAt,
    required this.lastAccessedAt,
    required this.cacheVersion,
    this.pendingSync = false,
    this.lastSyncErrorCode,
    this.lastSyncErrorMessage,
  });

  final String entityName;
  final String id;
  final Map<String, Object?> json;
  final DateTime updatedAt;
  final DateTime lastAccessedAt;
  final int cacheVersion;
  final bool pendingSync;
  final String? lastSyncErrorCode;
  final String? lastSyncErrorMessage;
}
```

### 7.3 Index cache entry

```dart
class CachedIndexRecord {
  const CachedIndexRecord({
    required this.endpoint,
    required this.argsHash,
    required this.entityName,
    required this.ids,
    required this.fetchedAt,
    required this.cacheVersion,
    this.lastRefreshErrorCode,
    this.lastRefreshErrorMessage,
  });

  final String endpoint;
  final String argsHash;
  final String entityName;
  final List<String> ids;
  final DateTime fetchedAt;
  final int cacheVersion;
  final String? lastRefreshErrorCode;
  final String? lastRefreshErrorMessage;
}
```

### 7.4 LRU policy

Default:

```text
maxItems = 1000 per entity type
```

Eviction rule:

```text
remove least recently accessed entity records
never evict pendingSync records
when deleting entity record, also remove its id from indexes
```

Reason:

```text
A single global cache limit is hard to reason about.
Per-entity limits keep UserSummary, Issue, Role, etc. independent.
```

### 7.5 Cache versioning

Add cache version to annotations:

```dart
@CachedQuery(
  entity: UserSummary,
  cacheVersion: 3,
)
```

Storage key should include version:

```text
v3/entity/UserSummary/123
v3/index/AdminEndpoint.listUsersByRole/<argsHash>
```

When model shape changes, increase version. Old cache can be ignored or cleared.

Reason:

```text
Old JSON may not deserialize after a model change.
A cache version is simpler and safer than complex local migrations for V1.
```

---

## 8. Storage adapter

### 8.1 Generic storage interface

Keep generated cache logic independent from Hive.

```dart
abstract interface class GeneratedCacheStorage {
  Future<String?> read(String key);

  Future<void> write(
    String key,
    String value,
  );

  Future<void> delete(String key);

  Future<List<String>> keysByPrefix(String prefix);

  Future<void> deleteByPrefix(String prefix);
}
```

Reason:

```text
Hive is a good first backend.
Later you may want SQLite, SharedPreferences for tiny cache, encrypted file storage, or Riverpod Storage.
The generated providers should not care.
```

### 8.2 Hive implementation

```dart
class HiveGeneratedCacheStorage implements GeneratedCacheStorage {
  HiveGeneratedCacheStorage(this._box);

  final Box<String> _box;

  @override
  Future<String?> read(String key) async {
    return _box.get(key);
  }

  @override
  Future<void> write(String key, String value) {
    return _box.put(key, value);
  }

  @override
  Future<void> delete(String key) {
    return _box.delete(key);
  }

  @override
  Future<List<String>> keysByPrefix(String prefix) async {
    return _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .toList();
  }

  @override
  Future<void> deleteByPrefix(String prefix) async {
    final keys = await keysByPrefix(prefix);
    await _box.deleteAll(keys);
  }
}
```

### 8.3 Secure storage routing

For `secure: true`, route to an encrypted storage instance.

```dart
final generatedCacheStorageProvider = FutureProvider<GeneratedCacheStorage>((ref) async {
  final box = await Hive.openBox<String>('generated_cache');
  return HiveGeneratedCacheStorage(box);
});

final generatedSecureCacheStorageProvider = FutureProvider<GeneratedCacheStorage>((ref) async {
  final key = await ref.watch(cacheKeyProvider.future);

  final box = await Hive.openBox<String>(
    'generated_secure_cache',
    encryptionCipher: HiveAesCipher(key),
  );

  return HiveGeneratedCacheStorage(box);
});
```

Do not encrypt by raw auth token.

Reason:

```text
tokens expire
tokens rotate
same user can receive a new token
logout may remove the token
old cache may become undecryptable
```

Better:

```text
use a stable per-user cache key
store/derive it through a CacheKeyProvider
clear it on logout if policy requires
include userIdentifier in cache namespace
```

Example namespace:

```text
secure/user/<userIdentifier>/v3/entity/UserSummary/123
```

---

## 9. Generated query providers

### 9.1 Non-cached read endpoint

For a read endpoint without `@CachedQuery`, generate a normal provider with TTL.

```dart
static final listRoles = FutureProvider.autoDispose<List<Role>>((ref) async {
  ref.watch(refUpdateAllGeneratedProviders);
  ref.watch(refUpdateAll);

  final result = await ref.watch(clientProvider).admin.listRoles();

  ref.cacheFor(const Duration(minutes: 3));

  return result;
});
```

Generate this helper once:

```dart
extension GeneratedRefCacheFor on Ref {
  void cacheFor(Duration duration) {
    if (!mounted) return;
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}
```

Important detail:

```text
Call cacheFor after a successful request.
Do not keep failed requests alive for 3 minutes unless explicitly configured.
```

### 9.2 Cached list endpoint

For:

```dart
@CachedQuery(
  entity: UserSummary,
  idField: 'id',
  byIdMethod: 'getUserSummaryById',
)
Future<List<UserSummary>> listUsersByRole(
  Session session,
  String roleName,
)
```

Generate an `AsyncNotifierProvider.family`:

```dart
static final listUsersByRole = AsyncNotifierProvider.family<
  ListUsersByRoleController,
  List<UserSummary>,
  String
>(ListUsersByRoleController.new);
```

Generated controller:

```dart
class ListUsersByRoleController
    extends FamilyAsyncNotifier<List<UserSummary>, String> {
  @override
  Future<List<UserSummary>> build(String roleName) async {
    final cache = await ref.watch(userSummaryCacheProvider.future);

    final cached = await cache.readIndex(
      endpoint: 'AdminEndpoint.listUsersByRole',
      args: {'roleName': roleName},
    );

    if (cached != null && !cached.isExpired) {
      _refreshInBackground(roleName);
      return cached.items;
    }

    return _fetchAndCache(roleName);
  }

  Future<List<UserSummary>> _fetchAndCache(String roleName) async {
    final result = await ref
        .watch(clientProvider)
        .admin
        .listUsersByRole(roleName);

    final cache = await ref.read(userSummaryCacheProvider.future);

    await cache.putList(
      endpoint: 'AdminEndpoint.listUsersByRole',
      args: {'roleName': roleName},
      items: result,
      idOf: (item) => item.id.toString(),
    );

    return result;
  }

  Future<void> _refreshInBackground(String roleName) async {
    Future.microtask(() async {
      try {
        final fresh = await _fetchAndCache(roleName);

        if (ref.mounted) {
          state = AsyncData(fresh);
        }
      } catch (error, stackTrace) {
        ref.read(syncWarningCenterProvider.notifier).report(
          SyncWarning.connection(
            code: 'refresh_failed',
            message: aloc(
              'Latest update failed. Showing cached data.|Không cập nhật được dữ liệu mới nhất. Đang hiển thị dữ liệu đã lưu.|Не удалось получить последние данные. Показаны сохранённые данные.',
            ),
            retry: () => _fetchAndCache(roleName),
          ),
        );
      }
    });
  }
}
```

Reason:

```text
The user sees cached data immediately.
The provider refreshes in background.
If refresh fails, the UI is not spammed with errors; it gets one aggregated warning.
```

---

## 10. Generated mutation commands

### 10.1 Do not use `FutureProvider` for mutations

Do not generate this for mutations:

```dart
static final updateUserRole = FutureProvider.family<bool, (int, String)>(...);
```

Reason:

```text
FutureProvider represents a value.
A mutation is a command.
It should run only when explicitly called.
It should not be cached, recomputed, or watched like read data.
```

Generate command helpers and optional mutation controllers instead.

### 10.2 Generated command helper

For:

```dart
@MutationCommand(
  affects: UserSummary,
  idArg: 'userId',
  optimistic: OptimisticPolicy.patchLocalCache,
  retry: RetryPolicy.connectionOnly,
  refetch: RefetchPolicy.mergeReturnedEntity,
  idempotent: true,
)
Future<UserSummary> updateUserRole(
  Session session,
  int userId,
  String roleName,
)
```

Generate:

```dart
abstract final class RefAdminCommands {
  static Future<UserSummary> updateUserRole(
    Ref ref, {
    required int userId,
    required String roleName,
  }) async {
    final cache = await ref.read(userSummaryCacheProvider.future);
    final previous = await cache.getById(userId.toString());

    await cache.patchById(
      userId.toString(),
      (user) => user.copyWith(roleName: roleName),
      pendingSync: true,
    );

    _invalidateUserSummaryViews(ref);

    try {
      final updated = await ref
          .read(clientProvider)
          .admin
          .updateUserRole(userId, roleName);

      await cache.putOne(
        updated,
        id: updated.id.toString(),
        pendingSync: false,
      );

      invalidateAfterUpdateUserRole(
        ref,
        userId: userId,
        roleName: roleName,
      );

      return updated;
    } catch (error, stackTrace) {
      final mapped = ref.read(generatedErrorMapperProvider).map(error);

      if (mapped.kind == GeneratedErrorKind.connection) {
        await ref.read(retryQueueProvider.notifier).enqueue(
          QueuedOperation(
            endpoint: 'AdminEndpoint',
            method: 'updateUserRole',
            args: {
              'userId': userId,
              'roleName': roleName,
            },
            retryAfter: const Duration(seconds: 10),
          ),
        );

        ref.read(syncWarningCenterProvider.notifier).report(
          SyncWarning.connection(
            code: 'mutation_queued',
            message: aloc(
              'Latest update failed. Retrying soon.|Không cập nhật được dữ liệu mới nhất. Sẽ tự thử lại.|Не удалось обновить данные. Повтор будет выполнен автоматически.',
            ),
          ),
        );

        rethrow;
      }

      if (previous == null) {
        await cache.removeById(userId.toString());
      } else {
        await cache.putOne(
          previous,
          id: previous.id.toString(),
          pendingSync: false,
        );
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static void invalidateAfterUpdateUserRole(
    Ref ref, {
    required int userId,
    required String roleName,
  }) {
    ref.invalidate(RefAdminEndpoint.getUserSummaryById(userId));
    ref.invalidate(RefAdminEndpoint.listUsersByRole);
    ref.invalidate(RefAdminEndpoint.listUsersByDepartment);
  }

  static void _invalidateUserSummaryViews(Ref ref) {
    ref.invalidate(RefAdminEndpoint.listUsersByRole);
    ref.invalidate(RefAdminEndpoint.listUsersByDepartment);
  }
}
```

### 10.3 Optional generated mutation controller

```dart
final adminMutationControllerProvider =
    AsyncNotifierProvider<AdminMutationController, void>(
  AdminMutationController.new,
);

class AdminMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateUserRole({
    required int userId,
    required String roleName,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await RefAdminCommands.updateUserRole(
        ref,
        userId: userId,
        roleName: roleName,
      );
    });
  }
}
```

UI example:

```dart
await ref
    .read(adminMutationControllerProvider.notifier)
    .updateUserRole(
      userId: user.id,
      roleName: selectedRole,
    );

final result = ref.read(adminMutationControllerProvider);

if (result.hasError) {
  // Keep dialog open and show error.
}
```

Actual `Navigator.pop()` stays in the UI. Generated code exposes state; it does not navigate.

---

## 11. Invalidation rules

### 11.1 Default invalidation

Default for a mutation affecting `T`:

```text
invalidate all generated query providers returning T or List<T>
```

Reason:

```text
Safe and simple.
May refetch more than necessary.
Good default for V1.
```

### 11.2 Precise invalidation

Use annotation for precision:

```dart
@MutationCommand(
  affects: UserSummary,
  idArg: 'userId',
  invalidate: [
    Invalidate.family('getUserSummaryById', argFrom: 'userId'),
    Invalidate.all('listUsersByRole'),
    Invalidate.all('listUsersByDepartment'),
  ],
)
Future<UserSummary> updateUserRole(...)
```

Generated:

```dart
ref.invalidate(RefAdminEndpoint.getUserSummaryById(userId));
ref.invalidate(RefAdminEndpoint.listUsersByRole);
ref.invalidate(RefAdminEndpoint.listUsersByDepartment);
```

### 11.3 Selected UI state must remain separate

Example:

```dart
final selectedRoleProvider = StateProvider<String?>((ref) => null);

final usersForSelectedRoleProvider = FutureProvider.autoDispose((ref) {
  final role = ref.watch(selectedRoleProvider);

  if (role == null) {
    return <UserSummary>[];
  }

  return ref.watch(RefAdminEndpoint.listUsersByRole(role).future);
});
```

When generated mutation invalidates `listUsersByRole`, the selected role remains unchanged.

Reason:

```text
Generated endpoint providers should cache data.
They should not own screen-specific state like selected tab, filter, expanded row, or dialog content.
```

---

## 12. Retry queue

### 12.1 Read retry

Riverpod can retry failed providers. Use it for read endpoints if desired.

Read retry is simple:

```text
listUsersByRole failed
→ retry later
→ no mutation side effects
```

### 12.2 Mutation retry

Mutation retry must be explicit and safer.

Only auto-retry when:

```text
retry = RetryPolicy.connectionOnly
idempotent = true
arguments are serializable
operation is not dangerous
```

Safe examples:

```text
updateUserRole(userId, roleName)
setIssueStatus(issueId, status)
saveDraft(id, content)
```

Unsafe examples unless explicitly designed:

```text
runBackup()
sendEmail()
createPayment()
submitApproval()
createIssue() without idempotency key
bulk import
```

### 12.3 Queued operation format

```dart
class QueuedOperation {
  const QueuedOperation({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.args,
    required this.retryAt,
    required this.attempt,
    required this.createdAt,
  });

  final String id;
  final String endpoint;
  final String method;
  final Map<String, Object?> args;
  final DateTime retryAt;
  final int attempt;
  final DateTime createdAt;
}
```

Persist queued operations only if the mutation is annotated as idempotent.

### 12.4 Create operations need idempotency key

Bad:

```dart
Future<Issue> createIssue(
  Session session,
  String title,
)
```

If connection fails after server created the issue, retry may create a duplicate.

Better:

```dart
@MutationCommand(
  affects: Issue,
  retry: RetryPolicy.connectionOnly,
  idempotent: true,
  idempotencyKeyArg: 'clientRequestId',
)
Future<Issue> createIssue(
  Session session,
  String clientRequestId,
  String title,
)
```

Server stores/recognizes `clientRequestId` and returns the existing result on retry.

---

## 13. Warning aggregator

### 13.1 Why it is needed

If 100 providers refresh in background and the network is down, the app must not show 100 snackbars.

Every generated provider/command reports warnings to one center:

```dart
final syncWarningCenterProvider =
    NotifierProvider<SyncWarningCenter, SyncWarningState>(
  SyncWarningCenter.new,
);
```

### 13.2 Warning state

```dart
class SyncWarningState {
  const SyncWarningState({
    this.pendingRetryCount = 0,
    this.failedRefreshCount = 0,
    this.nextRetryAt,
    this.lastMessage,
  });

  final int pendingRetryCount;
  final int failedRefreshCount;
  final DateTime? nextRetryAt;
  final String? lastMessage;

  bool get hasWarning =>
      pendingRetryCount > 0 || failedRefreshCount > 0 || lastMessage != null;
}
```

### 13.3 Aggregation rules

```text
same error kind within 10 seconds → merge
same endpoint/entity → increment count
show one banner
include retry countdown
include retry now button
```

### 13.4 UI banner

```dart
class SyncWarningBanner extends ConsumerWidget {
  const SyncWarningBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warning = ref.watch(syncWarningCenterProvider);

    if (!warning.hasWarning) {
      return const SizedBox.shrink();
    }

    return MaterialBanner(
      content: Text(
        aloc(
          'Latest update failed. Some data may be outdated.|Không cập nhật được dữ liệu mới nhất. Một số dữ liệu có thể đã cũ.|Не удалось обновить данные. Часть данных может быть устаревшей.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(retryQueueProvider.notifier).retryNow();
          },
          child: Text(
            aloc('Retry now|Thử lại ngay|Повторить сейчас'),
          ),
        ),
      ],
    );
  }
}
```

---

## 14. Error handling

### 14.1 Generated error kinds

```dart
enum GeneratedErrorKind {
  connection,
  timeout,
  unauthorized,
  forbidden,
  validation,
  conflict,
  notFound,
  server,
  unknown,
}
```

### 14.2 Default user messages

```text
connection   → Connection lost. Showing cached data.
timeout      → Server did not respond. Please try again.
unauthorized → Your session expired. Please log in again.
forbidden    → You do not have permission to do this.
validation   → Please check the entered data.
conflict     → This data was changed by someone else.
notFound     → The requested record was not found.
server       → Server error. Please try again later.
unknown      → Unexpected error.
```

### 14.3 Structured server exceptions

For good generated UI messages, backend should throw structured exceptions.

Example:

```dart
class AppException implements Exception {
  const AppException({
    required this.code,
    required this.message,
    this.details = const {},
  });

  final String code;
  final String message;
  final Map<String, Object?> details;
}
```

Example server usage:

```dart
throw AppException(
  code: 'role_not_allowed_for_department',
  message: 'This role cannot be assigned to this department.',
  details: {
    'roleName': roleName,
    'departmentId': departmentId,
  },
);
```

Generated mapper can then show:

```dart
aloc(
  'This role cannot be assigned to this department.|Không thể gán vai trò này cho phòng ban này.|Эту роль нельзя назначить данному подразделению.',
)
```

---

## 15. Secure cache

### 15.1 Annotation

```dart
@CachedQuery(
  entity: UserSummary,
  secure: true,
)
Future<List<UserSummary>> listUsersByDepartment(...)
```

### 15.2 Generated behavior

```text
secure: false
  → normal cache storage

secure: true
  → secure cache storage
  → per-user namespace
  → encrypted box/storage if configured
  → clear on logout if policy says so
```

### 15.3 Key provider

```dart
abstract interface class CacheKeyProvider {
  Future<List<int>> keyForCurrentUser();

  Future<String> userCacheNamespace();

  Future<void> clearCurrentUserKey();
}
```

### 15.4 Logout behavior

```dart
Future<void> onLogout(WidgetRef ref) async {
  ref.read(retryQueueProvider.notifier).clear();
  ref.read(syncWarningCenterProvider.notifier).clear();

  final cacheStorage = await ref.read(generatedCacheStorageProvider.future);
  final secureStorage = await ref.read(generatedSecureCacheStorageProvider.future);

  await cacheStorage.deleteByPrefix('user/');
  await secureStorage.deleteByPrefix('secure/user/');
}
```

Exact deletion policy can be configurable:

```text
clear all secure cache on logout
keep secure cache but key is removed
clear only current user namespace
```

V1 recommendation:

```text
clear current user's secure cache on logout
```

---

## 16. Generator phases

### Phase 0 — Minimal spike

Status: DONE, compacted.

Completed in the current Riverpod 3 foundation:

```text
annotation package
build_runner builder package
Serverpod Endpoint scanner
Session-first-parameter safeguard
generated static FutureProvider wrappers
generated family providers for endpoint arguments
generated TTL cache after successful calls
Riverpod 3 retry: _noProviderRetry on generated endpoint providers
generated invalidation hooks
auto-applied builder with no required consumer build.yaml
```

Deferred from the larger plan:

```text
@CachedQuery
@MutationCommand
frontend runtime cache
mutation command controllers
```

### Phase 0.5 — Future annotation API

Status: DONE.

Completed:

```text
@CachedQuery
@MutationCommand
Invalidate.all / Invalidate.family
CacheMergePolicy
OptimisticPolicy
RetryPolicy
RefetchPolicy
DialogPolicy
@ValidateString
@ValidateNumber
@ValidateList
annotation package tests
```

Still open:

```text
additional diagnostics for rare invalid annotation combinations not yet covered
```

### Phase 1 — Manifest generator

Status: DONE for V1 (manifest emitted + drives generator).

Done:

```text
AST metadata readers for @CachedQuery
AST metadata readers for @MutationCommand
AST metadata readers for Invalidate.all / Invalidate.family
AST metadata readers for validation annotations
internal endpoint manifest builder
generatedEndpointManifest typed const object output
runtime EndpointManifest / EndpointInfo / MethodInfo classes
parser tests
manifest builder tests
manifest emitter tests
consumption by generator to emit Ref* providers, entity cache wiring, and mutation commands
```

Still open:

```text
optional: use manifest in runtime-only debugging tools / secondary codegen paths
```

Reason:

```text
The manifest is easier to debug than direct code generation only.
It gives you one generated description of all endpoint/cache decisions.
```

### Phase 2 — Runtime cache

Status: PARTIAL.

Done:

```text
riverpod_for_serverpod_runtime package
GeneratedCacheStorage
MemoryGeneratedCacheStorage
GeneratedKeyValueStorage
MemoryGeneratedKeyValueStorage
JsonGeneratedCacheStorage
riverpod_for_serverpod_hive_storage package
HiveGeneratedKeyValueStorage
openHiveGeneratedCacheStorage
openHiveGeneratedKeyValueStorage
GeneratedEntityCache<T>
CachedEntityRecord
CachedIndexRecord
JSON encode/decode callbacks
record toJson/fromJson serialization
cache version support
TTL freshness for indexes
  offline fallback reads for stale indexes
  LRU eviction by maxItems
  pendingSync records are not evicted
  InMemoryMutationRetryQueue (schedule, retryNow, retryAllReady)
runtime cache tests
```

Still open:

```text
optional: expand automated tests for every checklist row below (many are already covered — see package tests)
```

Tests:

```text
putOne/getById
putList/readIndex
LRU removes old records
pendingSync records are not evicted
cacheVersion mismatch ignores old record
stale fallback returns expired index records
stale fallback returns null when indexed entity is missing
record JSON round trip
```

### Phase 3 — Query provider generation

Status: DONE for core SWR + cache; optional E2E polish remains.

Done:

```text
simple FutureProvider for non-cached reads
family providers for endpoint arguments
TTL keepAlive for successful calls
refreshWarningProvider recordFailure for @CachedQuery provider failures (then rethrow)
AsyncNotifierProvider SWR for @CachedQuery with backgroundRefresh: true
stale-while-revalidate using GeneratedEntityCache
```

Still open for this phase (optional):

```text
additional end-to-end / integration scenarios beyond unit coverage
```

Tests:

```text
first load calls remote and caches result
second load reads cache
expired cache refreshes
offline refresh shows cached data and reports one warning
```

### Phase 4 — Mutation command generation

Status: PARTIAL.

Done:

```text
method-level invalidateAfter<MethodName>(ref.read) hooks
endpoint-level updateAll(ref.read) hooks
cross-endpoint invalidation via @RefInvalidate
abstract final class Ref<Endpoint>Commands with static async methods for @MutationCommand
wiring to mutationRetryQueueProvider on connection-like failures (idempotent + retry enabled)
queued retry warning reporting through refreshWarningProvider
AsyncNotifier<void> mutation controller per endpoint with @MutationCommand methods
```

Still open for command generation:

Generate (done in current repo unless noted):

```text
optimistic patch logic (pendingSync + rollback; refetch merge/byId when entity cache template from @CachedQuery exists)
rollback logic (non-retry failures restore previous entity snapshot)
success merge/refetch logic beyond invalidate hooks (mergeReturnedEntity, byId)
```

Still open — tests / polish:

```text
domain failure rolls back optimistic patch (integration-style tests)
```


### Phase 5 — Retry queue

Status: PARTIAL (in-memory + optional persistence for idempotent ops).

Implement:

```text
in-memory retry queue for V1 (done)
optional persisted retry queue for idempotent operations (done — JSON via GeneratedKeyValueStorage + replay registry + generated registrations)
exponential backoff or fixed countdown (fixed / attempt backoff in memory)
retry now API (done)
warning center integration (done)
```

Tests:

```text
connection failure enqueues operation (covered by generator/runtime tests)
retry now calls command (done)
successful retry clears pendingSync (app-level / optimistic paths)
non-idempotent mutation is not persisted (payload only emitted when idempotent)
```


### Phase 6 — Warning aggregator

Status: PARTIAL.

Done:

```text
RefreshWarningState / RefreshWarningNotifier / refreshWarningProvider
generated @CachedQuery FutureProvider bodies call recordFailure then rethrow
generated mutation commands call recordQueuedMutation after scheduling retry
mutationRetryQueueProvider clears/updates queued mutation warning count after queue changes
generated cached-query success paths call clearRefreshFailures without clearing queued mutation warnings
```

Still open:

```text
nextRetryAt countdown for background cache refresh failures (distinct from queued-mutation nextRetryAt)
```


### Phase 7 — Secure cache

Status: PARTIAL.

Done:

```text
secure flag routing
per-user namespace
encrypted Hive storage
logout clear API
```

Still open:

```text
secure storage override examples in larger demo apps (runtime integration test covers provider isolation)
diagnostic when secure cached queries are used without reviewing storage override (done — manifest warning secure_cached_query_requires_override)
```


Tests:

```text
secure query writes to secure storage
normal query writes to normal storage
logout clears secure namespace (runtime key-value helper)
user A does not read user B cache (runtime namespace wrapper)
```

### Phase 8 — Diagnostics and lint-like warnings

Status: PARTIAL.

Done:

```text
conflicting @CachedQuery + @MutationCommand diagnostic
unsupported cached query return type diagnostic
invalid cache maxItems diagnostic
invalid cacheVersion diagnostic
retry without idempotent diagnostic
idempotencyKeyArg without idempotent diagnostic
bool mutation without byIdMethod diagnostic
mutation-like method without @MutationCommand diagnostic
create mutation retry without idempotency key diagnostic
missing annotation parameter reference diagnostic
builder warning/severe logging
diagnostics tests
```

Still open:

Generate diagnostics for:

```text
cached query return type is unsupported
idField does not exist on entity
mutation returns bool but no byIdMethod/refetch policy is configured
retry requested but mutation is not idempotent
secure requested but no secure storage provider is configured
cache maxItems is too small
```

### Phase 9 — Documentation and examples

Status: PARTIAL.

Done:

```text
root README
package READMEs
controller generator design draft
riverpod_2_and_3_compatibility guide
MIT licenses
Riverpod 2.6 compatibility notes
```

Still open:

Create examples:

```text
admin roles example
issue list example
by-id detail example
update mutation example
offline fallback example
secure cache example
retry queue example
frontend test with Memory storage
```

---

## 17. Recommended V1 scope

Build this first:

```text
@CachedQuery for List<T> and T/T? by id
generated entity/index Hive cache
generated read AsyncNotifier providers
@MutationCommand for update/delete only
connection-only retry queue
one warning aggregator
secure flag only routes/clears cache; encryption can be V2
basic validation annotations
broad invalidation by affected type
```

Avoid in V1:

```text
offline create without idempotency key
bulk import retry
send email retry
run backup retry
complex conflict resolution
automatic deep business validation
fully generated screen controllers
binary/file upload caching
```

Reason:

```text
V1 should prove the architecture with low-risk data flows.
Offline creates, conflict resolution, and dangerous commands can be added after the core is stable.
```

---

## 18. Remaining decisions before coding

| Decision | Recommended default | Why it matters |
|---|---|---|
| Canonical ID field | `id` | Cache needs stable entity keys. |
| Non-`id` fields | Require `idField` annotation | Some models use `ma`, `uuid`, `externalUserId`. |
| Server error format | Use structured `AppException` | Needed for user-friendly generated errors. |
| Mutation retry | Only `idempotent: true` | Prevent duplicate creates/emails/payments. |
| Create retry | Require idempotency key | Avoid duplicate rows after connection drop. |
| Conflict policy | Server wins | Safest default. |
| Cache migration | Cache version reset | Simpler than local migration for generated cache. |
| Secure cache key | Per-user key, not token | Tokens rotate/expire. |
| UI navigation | Not generated | Generated code should not call `Navigator.pop`. |
| Selected filters | Hand-written UI providers | Avoid losing selected tab/filter during invalidation. |
| Family invalidation | Broad by default, precise by annotation | Safe default, optimization later. |
| Provider persistence | Generated cache runtime first | Riverpod persistence is useful but not enough for mutation queues and entity indexes. |

---

## 19. Example end-to-end flow

### Backend

```dart
class AdminEndpoint extends Endpoint {
  @CachedQuery(
    entity: UserSummary,
    idField: 'id',
    secure: true,
    byIdMethod: 'getUserSummaryById',
  )
  Future<List<UserSummary>> listUsersByRole(
    Session session,
    String roleName,
  ) async {
    return AdminService(session).listUsersByRole(roleName);
  }

  @CachedQuery(
    entity: UserSummary,
    idField: 'id',
    secure: true,
  )
  Future<UserSummary?> getUserSummaryById(
    Session session,
    int userId,
  ) async {
    return AdminService(session).getUserSummaryById(userId);
  }

  @ValidateString(
    arg: 'roleName',
    notEmpty: true,
    maxLength: 50,
  )
  @MutationCommand(
    affects: UserSummary,
    idArg: 'userId',
    optimistic: OptimisticPolicy.patchLocalCache,
    retry: RetryPolicy.connectionOnly,
    refetch: RefetchPolicy.mergeReturnedEntity,
    idempotent: true,
    invalidate: [
      Invalidate.all('listUsersByRole'),
      Invalidate.all('listUsersByDepartment'),
      Invalidate.family('getUserSummaryById', argFrom: 'userId'),
    ],
  )
  Future<UserSummary> updateUserRole(
    Session session,
    int userId,
    String roleName,
  ) async {
    return AdminService(session).updateUserRole(
      userId: userId,
      roleName: roleName,
    );
  }
}
```

### Generated frontend read usage

```dart
class UsersByRolePage extends ConsumerWidget {
  const UsersByRolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(selectedRoleProvider);

    if (role == null) {
      return const Center(child: Text('Select role'));
    }

    final usersState = ref.watch(
      RefAdminEndpoint.listUsersByRole(role),
    );

    return usersState.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stackTrace) => Text('$error'),
      data: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            title: Text(user.name),
            subtitle: Text(user.roleName),
          );
        },
      ),
    );
  }
}
```

### Generated frontend mutation usage

```dart
await ref
    .read(adminMutationControllerProvider.notifier)
    .updateUserRole(
      userId: user.id,
      roleName: newRoleName,
    );

final commandState = ref.read(adminMutationControllerProvider);

if (commandState.hasError) {
  // Keep dialog open and show validation/domain error.
} else {
  // Close dialog only after confirmed success.
}
```

### Global warning banner

```dart
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SyncWarningBanner(),
        Expanded(child: AppRouterOutlet()),
      ],
    );
  }
}
```

---

## 20. Final recommendation

Do not generate one giant all-knowing frontend controller.

Generate these layers instead:

```text
1. endpoint manifest
2. cached query providers
3. entity/index cache providers
4. mutation command helpers
5. optional mutation controller
6. retry queue
7. warning aggregator
8. invalidation helpers
```

Keep this hand-written:

```text
screen-specific selected filters
current tab/current row/dialog state
complex workflow validation
custom conflict UI
navigation behavior
```

This gives most of the “write once on backend” benefit while keeping the dangerous UI/business decisions explicit.
