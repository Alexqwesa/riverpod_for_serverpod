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

See [Riverpod 2 and 3 compatibility](../riverpod_2_and_3_compatibility.md) for
generated `Ref.cacheFor` behavior and Riverpod 3 automatic retry handling.

Riverpod 2 vs 3 codegen is chosen from sibling pubspecs next to the server
package: `*_flutter` first, then `*_client`, then the server pubspec.

## What it generates

- `Ref...Endpoint` classes for Serverpod endpoint classes
- read providers and cached-query notifiers
- mutation command helpers and mutation controllers
- endpoint-level `updateAll(ref.read)` invalidation hooks
- method-level `invalidateAfter<MethodName>(ref.read, ref.invalidate)` hooks
- typed endpoint manifest metadata

## Supported annotations

- `@CachedQuery(...)`
- `@MutationCommand(...)`
- `@ValidateString(...)`
- `@ValidateNumber(...)`
- `@ValidateList(...)`
- `@CacheTtl(...)`
- `@Timeout(...)`
- `@RefInvalidate([...])` (legacy; prefer `MutationCommand.invalidate`)
- `@DoNotGenerate()`

## Serverpod trio setup

### Server (`*_server`)

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

  @MutationCommand(
    affects: User,
    retry: RetryPolicy.none,
    invalidate: [
      Invalidate.self(AdminEndpoint),
      Invalidate.endpoint(UserEndpoint),
    ],
  )
  Future<void> updateUsersRole(
    Session session,
    List<int> userIds,
    String roleName,
  ) async {
    ...
  }
}
```

Generate and copy into the client:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run riverpod_for_serverpod_generator:copy_ref_endpoints
```

`copy_ref_endpoints` also fills missing dependencies across server / client /
Flutter by default. Use `--no-ensure-deps` to skip that.

Committed goldens for the example live at:

- `example/selector_demo/selector_demo_server/lib/src/generated/ref_endpoints.dart`
- `example/selector_demo/selector_demo_client/lib/ref_endpoints.dart`

Regenerate them and assert they match git HEAD:

```bash
cd riverpod_for_serverpod_generator
dart test test/selector_demo_codegen_e2e_test.dart
```

If that test reports drift, commit both regenerated files.

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

Or define a Serverpod script:

```yaml
serverpod:
  scripts:
    ref_endpoints:
      windows: >-
        dart run build_runner build --delete-conflicting-outputs
        & dart run riverpod_for_serverpod_generator:copy_ref_endpoints
      posix: |
        dart run build_runner build --delete-conflicting-outputs &&
        dart run riverpod_for_serverpod_generator:copy_ref_endpoints
```

Then run:

```bash
serverpod run ref_endpoints
```

### Client (`*_client`)

```yaml
dependencies:
  riverpod: ^3.0.0
  riverpod_for_serverpod_runtime: ^3.0.0
  serverpod_auth_client: 3.4.4 # match serverpod_client
  serverpod_client: 3.4.4
```

Export the copied generated file from the client library:

```dart
export 'ref_endpoints.dart';
```

### Flutter app (`*_flutter`)

```yaml
dependencies:
  flutter_riverpod: ^3.0.0
  your_project_client:
    path: ../your_project_client
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
RefBankManagerEndpoint.invalidateAfterUpsertBankProfile(
  ref.read,
  ref.invalidate,
);
```

Because `upsertBankProfile` can declare
`invalidate: [Invalidate.self(BankManagerEndpoint), Invalidate.endpoint(BankBalanceEndpoint)]`,
that single call refreshes both `RefBankManagerEndpoint` and
`RefBankBalanceEndpoint`.

Methods annotated with `@MutationCommand` are generated as explicit command
helpers instead of watched `FutureProvider` values:

```dart
await RefAdminEndpointCommands.updateUserRole(
  ref.read,
  ref.invalidate,
  userId,
  roleName,
);
```

For UI loading/error state, the generator also emits one mutation controller per
endpoint with mutation commands:

```dart
await ref
    .read(adminMutationControllerProvider.notifier)
    .updateUserRole(userId, roleName);
```

## Diagnostics

The builder emits warnings for risky annotation combinations. Methods whose
names look mutation-like, such as `updateRole`, `deleteUser`, or `upsertBank`,
produce a warning unless they are annotated with `@MutationCommand`,
`@CachedQuery`, or `@DoNotGenerate()`.

Create-like mutation names, such as `createIssue` or `addDraft`, also warn when
retry is enabled without `idempotencyKeyArg`, because a retry after connection
loss can create duplicates.

Annotation fields that reference method parameters are validated. For example,
`idArg`, `idempotencyKeyArg`, `Invalidate.providerFamily(..., argFrom: ...)`, and
validation annotation `arg` values must match real endpoint method parameters.
