# riverpod_for_serverpod_annotation

Annotations used by `riverpod_for_serverpod_generator`.

## Compatibility

This package follows the Riverpod compatibility line used by the generator.
Version `3.x` targets Riverpod `3.x`. For Riverpod `2.6.x`, use the `2.6.x`
package line/branch.

## Available annotations

### `@CachedQuery`

Marks a read endpoint for future generated entity/index cache support.

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

Marks a state-changing endpoint as a future generated command instead of a
cached read provider.

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
    Invalidate.family('getUserSummaryById', argFrom: 'userId'),
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

### `@ValidateString`, `@ValidateNumber`, `@ValidateList`

Stores simple input validation metadata for future generated client-side checks.
Business validation should stay on the server.

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

Controls how long the generated Riverpod provider stays alive before it can be
disposed when unused.

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

### `@RefInvalidate`

Declares generated invalidation hooks for successful mutations.

The generated `Ref...Endpoint.invalidateAfter<MethodName>(ref.read)` helper
always refreshes the current endpoint. `endpoints` adds extra endpoint refs to
refresh too.

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
RefAdminEndpoint.invalidateAfterUpdateUsersRole(ref.read);
```

### `@DoNotGenerate`

Skips a method or endpoint class entirely.

```dart
@DoNotGenerate()
Future<void> internalOnly(Session session) async {
  ...
}
```
