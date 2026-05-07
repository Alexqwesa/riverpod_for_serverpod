# Serverpod Riverpod Controller Generator

Generate Riverpod frontend providers, offline cache, mutation commands, retry handling, and cache invalidation from annotated Serverpod endpoints.

The package is designed for projects where Serverpod is the backend and Riverpod is the Flutter frontend state layer.

```text
Serverpod endpoint + annotations
  → generated Riverpod query providers
  → generated entity cache
  → generated mutation commands
  → generated retry queue
  → generated warning aggregator
```

## Why use this package?

Without this package, you often write the same code many times:

```text
call Serverpod client endpoint
store data in provider
keep result alive for N minutes
load cached data when offline
invalidate related providers after update
retry failed connection updates
show one global warning instead of 100 snackbars
```

This package moves that repeatable logic into annotations and generated code.

You still write UI-specific logic yourself:

```text
selected tab
selected role/filter
open/close dialog
custom validation UI
navigation
complex workflow conflict screen
```

## Main idea

Write backend endpoint:

```dart
class AdminEndpoint extends Endpoint {
  @CachedQuery(
    entity: UserSummary,
    idField: 'id',
    byIdMethod: 'getUserSummaryById',
    secure: true,
  )
  Future<List<UserSummary>> listUsersByRole(
    Session session,
    String roleName,
  ) async {
    return AdminService(session).listUsersByRole(roleName);
  }

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
  ) async {
    return AdminService(session).updateUserRole(
      userId: userId,
      roleName: roleName,
    );
  }
}
```

Use generated frontend code:

```dart
final usersState = ref.watch(
  RefAdminEndpoint.listUsersByRole('admin'),
);
```

Call generated mutation command/controller:

```dart
await ref
    .read(adminMutationControllerProvider.notifier)
    .updateUserRole(
      userId: 123,
      roleName: 'operator',
    );
```

The generated code handles:

```text
cache read
cache write
background refresh
offline fallback
connection-error retry
cache invalidation
warning aggregation
```

## Packages

Recommended package layout:

```text
serverpod_riverpod_annotations
  annotation classes used on Serverpod endpoints

serverpod_riverpod_runtime
  runtime cache/retry/warning classes used by generated frontend code

serverpod_riverpod_hive_storage
  optional Hive storage adapter

serverpod_riverpod_generator
  build_runner/source_gen generator
```

## Installation

Add annotations to the Serverpod server package:

```yaml
dependencies:
  serverpod_riverpod_annotations:
    path: ../packages/serverpod_riverpod_annotations
```

Add runtime and generator to the Flutter client package:

```yaml
dependencies:
  flutter_riverpod: ^3.0.0
  serverpod_riverpod_runtime:
    path: ../packages/serverpod_riverpod_runtime
  serverpod_riverpod_hive_storage:
    path: ../packages/serverpod_riverpod_hive_storage

dev_dependencies:
  build_runner: any
  serverpod_riverpod_generator:
    path: ../packages/serverpod_riverpod_generator
```

Add the generated part file where your generated frontend providers should live:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_project_client/my_project_client.dart';
import 'package:serverpod_riverpod_runtime/serverpod_riverpod_runtime.dart';

part 'generated_serverpod_providers.g.dart';
```

Run generation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Required frontend providers

The generated code expects a Serverpod client provider:

```dart
final clientProvider = Provider<Client>((ref) {
  return Client('http://localhost:8080/');
});
```

It also expects cache storage providers.

Simple non-secure Hive storage:

```dart
final generatedCacheStorageProvider =
    FutureProvider<GeneratedCacheStorage>((ref) async {
  final box = await Hive.openBox<String>('generated_cache');

  return HiveGeneratedCacheStorage(box);
});
```

Secure storage, if you use `secure: true`:

```dart
final generatedSecureCacheStorageProvider =
    FutureProvider<GeneratedCacheStorage>((ref) async {
  final key = await ref.watch(cacheKeyProvider.future);

  final box = await Hive.openBox<String>(
    'generated_secure_cache',
    encryptionCipher: HiveAesCipher(key),
  );

  return HiveGeneratedCacheStorage(box);
});
```

## Query annotation

Use `@CachedQuery` for read endpoints that should be cached.

```dart
@CachedQuery(
  entity: UserSummary,
  idField: 'id',
  maxItems: 1000,
  ttl: Duration(minutes: 3),
  secure: true,
  byIdMethod: 'getUserSummaryById',
)
Future<List<UserSummary>> listUsersByRole(
  Session session,
  String roleName,
)
```

### Parameters

| Parameter | Meaning |
|---|---|
| `entity` | Entity type stored in local cache. |
| `idField` | Field used as cache key. Default: `id`. |
| `maxItems` | Maximum cached entities for this type. Default: `1000`. |
| `ttl` | Time before cached index is considered stale. |
| `secure` | Store in secure/encrypted user cache. |
| `byIdMethod` | Endpoint method used to reload one entity by id. |
| `cacheVersion` | Increment when cached JSON shape changes. |

## Mutation annotation

Use `@MutationCommand` for methods that change server state.

```dart
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
)
```

### Parameters

| Parameter | Meaning |
|---|---|
| `affects` | Entity type affected by the mutation. |
| `idArg` | Method argument containing the entity id. |
| `idField` | Entity field containing id. Default: `id`. |
| `optimistic` | Whether to update local cache before server confirms. |
| `retry` | Retry policy for connection failures. |
| `refetch` | How cache is updated after server success. |
| `idempotent` | Whether retrying the operation is safe. |
| `idempotencyKeyArg` | Argument used to prevent duplicate creates. |
| `invalidate` | Providers/indexes to invalidate after success. |

## Do not use `FutureProvider` for mutations

Read endpoints are values:

```dart
final users = ref.watch(RefAdminEndpoint.listUsersByRole('admin'));
```

Mutation endpoints are commands:

```dart
await RefAdminCommands.updateUserRole(
  ref,
  userId: 123,
  roleName: 'operator',
);
```

Reason:

```text
FutureProvider may cache, rerun, or recompute.
A mutation must run only when explicitly called.
```

## Generated cache behavior

The generated cache has two layers:

```text
Entity cache:
  UserSummary/123 → UserSummary JSON
  UserSummary/124 → UserSummary JSON

Index cache:
  listUsersByRole('admin') → [123, 124]
  listUsersByDepartment(5) → [123, 200, 240]
```

Why not store every endpoint list as a full JSON blob?

```text
same entity can appear in many lists
one mutation should update one cached entity
all lists should then show the updated entity
cache limit should be per entity type
```

## Offline read behavior

For cached query providers:

```text
1. Try to read cached index.
2. If cache exists and TTL is valid, return cached data immediately.
3. Refresh from Serverpod in background.
4. If refresh succeeds, update cache and provider state.
5. If refresh fails, keep cached data and report one global warning.
```

User sees:

```text
Latest update failed. Some data may be outdated.
[Retry now]
```

## Mutation behavior

For optimistic mutations:

```text
1. Save previous cached entity.
2. Patch local cache and mark entity as pendingSync.
3. Call Serverpod mutation.
4. If success: store returned entity and clear pendingSync.
5. If connection error: enqueue retry and show one global warning.
6. If domain/server validation error: rollback local cache and return error.
```

Connection errors are treated differently from business errors.

Connection error:

```text
keep dialog/page open
show warning
retry automatically if operation is safe
keep pendingSync flag
```

Domain error:

```text
rollback optimistic local change
show normal error
do not auto-retry
```

## Retry queue

Only idempotent mutations should be retried automatically.

Safe example:

```dart
@MutationCommand(
  affects: UserSummary,
  retry: RetryPolicy.connectionOnly,
  idempotent: true,
)
Future<UserSummary> updateUserRole(...)
```

Unsafe by default:

```text
sendEmail
runBackup
createPayment
submitApproval
createIssue without idempotency key
```

For create operations, use an idempotency key:

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

Server should store `clientRequestId` and return the already-created row if the same request is retried.

## Warning aggregator

Generated providers do not show snackbars directly.

They report to:

```dart
final syncWarningCenterProvider =
    NotifierProvider<SyncWarningCenter, SyncWarningState>(
  SyncWarningCenter.new,
);
```

Add one banner near the app shell:

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

This prevents 100 failed background refreshes from creating 100 messages.

## Secure cache

Use `secure: true` for sensitive cached data:

```dart
@CachedQuery(
  entity: UserSummary,
  secure: true,
)
Future<List<UserSummary>> listUsersByDepartment(...)
```

Secure cache should use:

```text
per-user namespace
encrypted storage when configured
logout cleanup
```

Do not derive encryption directly from the raw auth token.

Reason:

```text
tokens expire
tokens rotate
same user may get a new token
old cached data may become undecryptable
```

Prefer a dedicated per-user cache key provider.

## Validation

Simple validation can be generated:

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
)
```

Generated check:

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
not empty
min/max length
numeric range
regex
list not empty
file size limit
```

Keep business validation on the server:

```text
user has permission
role exists
status transition is allowed
record is not locked
workflow step is active
```

## Error handling

Generated code maps raw errors into categories:

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

For best messages, throw structured server exceptions:

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

Then map error codes to localized messages:

```dart
aloc(
  'This role cannot be assigned to this department.|Không thể gán vai trò này cho phòng ban này.|Эту роль нельзя назначить данному подразделению.',
)
```

## UI pattern

Keep selected filters outside generated query providers.

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

When a mutation invalidates `listUsersByRole`, the selected role remains unchanged.

## Frontend tests

For UI tests, override generated providers or storage.

Example: use memory cache/storage instead of Hive:

```dart
testWidgets('shows users', (tester) async {
  final storage = MemoryGeneratedCacheStorage();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        generatedCacheStorageProvider.overrideWith(
          (ref) async => storage,
        ),
        clientProvider.overrideWithValue(fakeClient),
      ],
      child: const MyApp(),
    ),
  );

  expect(find.text('Alex'), findsOneWidget);
});
```

For backend endpoint tests, use Serverpod's normal server test tools. This package is for frontend provider/controller generation.

## Recommended V1 limitations

V1 should support:

```text
cached List<T> queries
cached T/T? by-id queries
Hive-backed entity/index cache
update/delete mutation commands
connection-only retry for idempotent mutations
warning aggregator
basic secure cache routing
basic validation annotations
```

V1 should avoid:

```text
offline create without idempotency key
send email retry
backup retry
payment retry
bulk import retry
binary/file upload caching
complex conflict resolution
fully generated screen controllers
```

## Troubleshooting

### Mutation generated as read provider

Add `@MutationCommand`.

Bad:

```dart
Future<bool> updateUserRole(...)
```

Good:

```dart
@MutationCommand(
  affects: UserSummary,
  idArg: 'userId',
)
Future<UserSummary> updateUserRole(...)
```

### Query not cached

Add `@CachedQuery` and ensure the return type is supported.

Supported V1 return types:

```text
T
T?
List<T>
```

Unsupported until configured:

```text
Page<T>
ApiResult<List<T>>
Map<String, T>
```

### Mutation returns `bool` and cache is stale

Prefer returning the updated entity:

```dart
Future<UserSummary> updateUserRole(...)
```

If you must return `bool`, configure by-id refetch:

```dart
@MutationCommand(
  affects: UserSummary,
  idArg: 'userId',
  byIdMethod: 'getUserSummaryById',
  refetch: RefetchPolicy.byId,
)
Future<bool> updateUserRole(...)
```

### Too many reloads after mutation

V1 may broadly invalidate all cached queries for the affected entity type.

Add precise invalidation:

```dart
invalidate: [
  Invalidate.family('getUserSummaryById', argFrom: 'userId'),
  Invalidate.all('listUsersByRole'),
]
```

### User sees old data

This can be normal if offline fallback is active.

Check:

```text
TTL setting
background refresh errors
sync warning banner
pending retry queue
cache version
```

## Best practices

Prefer mutation endpoints that return updated entity:

```dart
Future<UserSummary> updateUserRole(...)
```

Avoid mutation endpoints that return only `bool` unless you also provide a by-id endpoint.

Always annotate retry-safe mutations with:

```dart
idempotent: true
```

Use idempotency keys for creates.

Keep UI selection state outside generated providers.

Use secure cache only for data that really needs it; encrypted storage adds operational complexity.

Increase `cacheVersion` when model JSON shape changes.

Do not call `Navigator.pop()` inside generated code. Close dialogs only from UI after success state.

## Minimal complete example

Backend:

```dart
class IssueEndpoint extends Endpoint {
  @CachedQuery(
    entity: Issue,
    idField: 'id',
    byIdMethod: 'getIssueById',
  )
  Future<List<Issue>> listIssues(Session session) async {
    return Issue.db.find(session);
  }

  @CachedQuery(
    entity: Issue,
    idField: 'id',
  )
  Future<Issue?> getIssueById(Session session, int issueId) async {
    return Issue.db.findById(session, issueId);
  }

  @ValidateString(
    arg: 'title',
    notEmpty: true,
    maxLength: 200,
  )
  @MutationCommand(
    affects: Issue,
    idArg: 'issueId',
    optimistic: OptimisticPolicy.patchLocalCache,
    retry: RetryPolicy.connectionOnly,
    refetch: RefetchPolicy.mergeReturnedEntity,
    idempotent: true,
  )
  Future<Issue> updateIssueTitle(
    Session session,
    int issueId,
    String title,
  ) async {
    final issue = await Issue.db.findById(session, issueId);

    if (issue == null) {
      throw AppException(
        code: 'issue_not_found',
        message: 'Issue not found.',
      );
    }

    final updated = issue.copyWith(title: title.trim());
    return Issue.db.updateRow(session, updated);
  }
}
```

Frontend:

```dart
class IssueListPage extends ConsumerWidget {
  const IssueListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesState = ref.watch(RefIssueEndpoint.listIssues);

    return issuesState.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stackTrace) => Text('$error'),
      data: (issues) => ListView(
        children: [
          for (final issue in issues)
            ListTile(
              title: Text(issue.title),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  await ref
                      .read(issueMutationControllerProvider.notifier)
                      .updateIssueTitle(
                        issueId: issue.id!,
                        title: 'New title',
                      );
                },
              ),
            ),
        ],
      ),
    );
  }
}
```

## References

- Serverpod endpoint methods generate client calls when endpoint methods use typed `Future` return values and `Session` as the first parameter: https://docs.serverpod.dev/concepts/working-with-endpoints
- Riverpod providers cache values by provider identity/parameters and are commonly used for network requests: https://riverpod.dev/docs/concepts2/providers
- Riverpod automatic disposal and `keepAlive` can be used to implement TTL-style caching: https://riverpod.dev/docs/concepts2/auto_dispose
- Riverpod offline persistence is experimental and currently persists Notifier providers through a Storage adapter: https://riverpod.dev/docs/concepts2/offline
