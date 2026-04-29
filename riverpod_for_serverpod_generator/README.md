# riverpod_for_serverpod_generator

Build-runner generator that creates Riverpod providers for Serverpod endpoint
methods.

It scans server endpoint classes, then writes
`lib/src/generated/ref_endpoints.dart` in the server package. Host projects
usually copy that generated file into their `*_client` package as
`lib/ref_endpoints.dart`.

## What it generates

- `Ref...Endpoint` classes for Serverpod endpoint classes
- `FutureProvider` / `FutureProvider.family` wrappers for endpoint methods
- endpoint-level `updateAll(ref.read)` invalidation hooks
- method-level `invalidateAfter<MethodName>(ref.read)` hooks

## Supported annotations

- `@CacheTtl(...)`
- `@Timeout(...)`
- `@RefInvalidate([...])`
- `@DoNotGenerate()`

## Server setup

Add to server `pubspec.yaml`:

```yaml
dependencies:
  riverpod_for_serverpod_annotation:
    path: ../../riverpod_for_serverpod/riverpod_for_serverpod_annotation

dev_dependencies:
  build_runner: ^2.5.0
  riverpod_for_serverpod_generator:
    path: ../../riverpod_for_serverpod/riverpod_for_serverpod_generator
```

Add `build.yaml` to the server package:

```yaml
targets:
  $default:
    builders:
      riverpod_for_serverpod_generator|ref_endpoint:
        enabled: true
        options: {}
```

Annotate endpoint methods:

```dart
import 'package:riverpod_for_serverpod_annotation/riverpod_for_serverpod_annotation.dart';

class BankManagerEndpoint extends Endpoint {
  @CacheTtl(Duration(minutes: 10))
  Future<List<Bank>> listBanks(Session session) async {
    ...
  }

  @RefInvalidate(['BankBalanceEndpoint'])
  Future<BankProfile> upsertBankProfile(
    Session session,
    BankProfile bankProfile,
  ) async {
    ...
  }
}
```

Generate:

```bash
dart run build_runner build --delete-conflicting-outputs
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
  riverpod: ^2.6.1
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
