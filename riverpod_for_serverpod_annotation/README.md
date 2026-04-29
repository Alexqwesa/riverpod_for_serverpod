# riverpod_for_serverpod_annotation

Annotations used by `riverpod_for_serverpod_generator`.

## Available annotations

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
