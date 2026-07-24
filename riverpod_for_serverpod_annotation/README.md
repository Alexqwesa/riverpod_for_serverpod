# riverpod_for_serverpod_annotation

Annotations used by `riverpod_for_serverpod_generator`.

## Compatibility

This package follows the Riverpod compatibility line used by the generator.
Version `3.x` targets Riverpod `3.x`. For Riverpod `2.6.x`, use the `2.6.x`
package line/branch.

## Available annotations

### `@CachedQuery`

Marks a read endpoint for generated entity/index cache providers (SWR
`AsyncNotifier` by default, or `FutureProvider` when `backgroundRefresh: false`).

`ttl` drives both the entity-index TTL and Riverpod `ref.cacheFor` keepAlive.

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
) async {
  ...
}
```

### `@MutationCommand`

Marks a state-changing endpoint as a generated command helper (plus optional
mutation controller) instead of a watched read provider.

```dart
@MutationCommand(
  affects: UserSummary,
  idArg: 'userId',
  optimistic: OptimisticPolicy.patchLocalCache,
  retry: RetryPolicy.connectionOnly,
  refetch: RefetchPolicy.mergeReturnedEntity,
  idempotent: true,
  invalidate: [
    Invalidate.self(AdminEndpoint),
    Invalidate.provider(AdminEndpoint, 'listUsersByRole'),
    Invalidate.providerFamily(
      AdminEndpoint,
      'getUserSummaryById',
      argFrom: 'userId',
    ),
  ],
)
Future<UserSummary> updateUserRole(
  Session session,
  int userId,
  String roleName,
) async {
  ...
}
```

Generated client usage (Riverpod 2/3–friendly tear-offs):

```dart
await RefAdminEndpointCommands.updateUserRole(
  ref.read,
  ref.invalidate,
  userId,
  roleName,
);
```

### `@ValidateString`, `@ValidateNumber`, `@ValidateList`

Client-side validation helpers run in generated mutation commands before the
RPC. Business validation should stay on the server.

```dart
@ValidateString(
  arg: 'roleName',
  notEmpty: true,
  maxLength: 50,
)
Future<UserSummary> updateUserRole(
  Session session,
  int userId,
  String roleName,
) async {
  ...
}
```

### `@CacheTtl`

Controls Riverpod `cacheFor` keepAlive on **plain** read providers (methods
without `@CachedQuery`). For `@CachedQuery` methods, use `CachedQuery.ttl`.

```dart
@CacheTtl(Duration(minutes: 30))
Future<List<UserSummary>> listAllUsers(Session session) async {
  ...
}
```

### `@Timeout`

Adds a client-side `.timeout(...)` to the generated provider call.

```dart
@Timeout(Duration(minutes: 2))
Future<String> importUnitsFromMssql(Session session) async {
  ...
}
```

### `@RefInvalidate` legacy

Declares generated invalidation hooks for successful mutations. Prefer
`MutationCommand.invalidate` with `Invalidate.self`, `Invalidate.endpoint`, and
`Invalidate.provider` / `Invalidate.providerFamily` for new code.

```dart
@RefInvalidate(['UserSummaryEndpoint'])
Future<int> updateUsersRole(
  Session session,
  List<int> userIds,
  String roleName,
) async {
  ...
}
```

Generated client usage:

```dart
await client.admin.updateUsersRole(userIds, roleName);
RefAdminEndpoint.invalidateAfterUpdateUsersRole(ref.read, ref.invalidate);
```

### `@DoNotGenerate`

Skips a method or endpoint class entirely.

```dart
@DoNotGenerate()
Future<void> internalOnly(Session session) async {
  ...
}
```
