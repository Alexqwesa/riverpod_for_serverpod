# riverpod_for_serverpod_generator

Build-runner generator that creates Riverpod providers for Serverpod endpoint
methods.

It scans server endpoint classes, then writes
`lib/src/generated/ref_endpoints.dart` in the server package. Host projects
usually copy that generated file into their `*_client` package as
`lib/ref_endpoints.dart`.

## Compatibility

This generator targets Riverpod `3.x`. Package versions are aligned with the
supported Riverpod line, starting at `3.0.0`.

For Riverpod `2.6.x`, use the `2.6.x` package line/branch.

## What it generates

- `Ref...Endpoint` classes for Serverpod endpoint classes
- `FutureProvider` / `FutureProvider.family` wrappers for endpoint methods
- endpoint-level `updateAll(ref.read)` invalidation hooks
- method-level `invalidateAfter<MethodName>(ref.read)` hooks
- a small `Ref.cacheFor(...)` extension used by generated providers after a
  request succeeds

## Supported annotations

- `@CacheTtl(...)`
- `@Timeout(...)`
- `@RefInvalidate([...])`
- `@DoNotGenerate()`

## Server setup

Add to server `pubspec.yaml`:

```yaml
dependencies:
  riverpod_for_serverpod_annotation: ^3.0.0

dev_dependencies:
  build_runner: ^2.5.0
  riverpod_for_serverpod_generator: ^3.0.0
```

Annotate endpoint methods:

```dart
import 'package:riverpod_for_serverpod_annotation/riverpod_for_serverpod_annotation.dart';

class AdminEndpoint extends Endpoint {
  @CacheTtl(Duration(minutes: 10))
  Future<List<Role>> listRoles(Session session) async {
    ...
  }

  @RefInvalidate(['UserEndpoint'])
  Future<void> updateUsersRole(
    Session session,
    List<int> userIds,
    String roleName,
  ) async {
    ...
  }
}
```

The generated file includes providers like:

```dart
static final listRoles = FutureProvider.autoDispose<List<Role>>((ref) async {
  ref
    ..watch(refUpdateAllGeneratedProviders)
    ..watch(refUpdateAll);

  final result = await ref.watch(clientProvider).admin.listRoles();

  ref.cacheFor(const Duration(minutes: 10));

  return result;
});
```

`ref.cacheFor(...)` is generated after the awaited client call, so only
successful endpoint responses are kept alive.
Generated endpoint providers also set `retry: _noProviderRetry` to disable
Riverpod 3's default automatic retry; explicit offline/retry behavior belongs
in the future generated retry queue.

Generate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

No project-level `build.yaml` is required. The builder auto-applies to packages
that depend on `riverpod_for_serverpod_generator`, then only writes output when
it finds Serverpod endpoint methods with `Session` as the first parameter.

If a package depends on the generator but should not run it, disable it in that
package's `build.yaml`:

```yaml
targets:
  $default:
    builders:
      riverpod_for_serverpod_generator|ref_endpoint:
        enabled: false
```

Or define a Serverpod script so generation also copies the file into the client
package:

```yaml
serverpod:
  scripts:
    ref_endpoints:
      windows: >-
        dart run build_runner build --delete-conflicting-outputs
        && dart run riverpod_for_serverpod_generator:copy_ref_endpoints
      posix: |
        dart run build_runner build --delete-conflicting-outputs &&
        dart run riverpod_for_serverpod_generator:copy_ref_endpoints
```

Then run:

```bash
serverpod run ref_endpoints
```

## Client setup

Add to client `pubspec.yaml`:

```yaml
dependencies:
  riverpod: ^3.0.0
  serverpod_auth_client: 3.4.4
```

Export the copied generated file from the client library:

```dart
export 'ref_endpoints.dart';
```

Override the generated `clientProvider` in your app:

```dart
final container = ProviderContainer(
  overrides: [
    clientProvider.overrideWithValue(client),
  ],
);
```

Use generated providers:

```dart
final roleAsync = ref.watch(RefAuthEndpoint.getSelfRole);
final banksAsync = ref.watch(RefBankManagerEndpoint.listBanks);
final profilesAsync = ref.watch(RefBankManagerEndpoint.listProfiles(bankId));
```

Use generated hooks after successful mutations:

```dart
await client.bankManager.upsertBankProfile(profile);
RefBankManagerEndpoint.invalidateAfterUpsertBankProfile(ref.read);
```

Because `upsertBankProfile` was annotated with
`@RefInvalidate(['BankBalanceEndpoint'])`, that single call refreshes both
`RefBankManagerEndpoint` and `RefBankBalanceEndpoint`.

Methods annotated with `@MutationCommand` are generated as explicit command
helpers instead of watched `FutureProvider` values:

```dart
await RefAdminEndpointCommands.updateUserRole(ref.read, userId, roleName);
```

For UI loading/error state, the generator also emits one mutation controller per
endpoint with mutation commands:

```dart
await ref
    .read(adminMutationControllerProvider.notifier)
    .updateUserRole(userId, roleName);
```
