# riverpod_for_serverpod

Generate Riverpod providers for Serverpod endpoint methods.

This repository contains four Dart packages:

- `riverpod_for_serverpod_annotation`: annotations you add to Serverpod endpoints.
- `riverpod_for_serverpod_generator`: a `build_runner` builder that generates Riverpod providers.
- `riverpod_for_serverpod_runtime`: cache primitives used by generated providers.
- `riverpod_for_serverpod_hive_storage`: optional Hive storage adapter.

The generated file is written to `lib/src/generated/ref_endpoints.dart` in the server package. Most apps copy that generated file into the matching `*_client` package as `lib/ref_endpoints.dart`.

## Why

Serverpod already generates a typed client. This package adds a Riverpod layer on top of that client so Flutter apps can watch endpoint calls as providers, cache successful responses for a short time, and invalidate related endpoint providers after mutations.

## Compatibility

This line targets Riverpod `3.x`. Package versions are aligned with the supported Riverpod line, starting at `3.0.0`.

For Riverpod `2.6.x`, use the `2.6.x` package line/branch.

See [Riverpod 2 and 3 compatibility](riverpod_2_and_3_compatibility.md) for
generated `Ref.cacheFor` behavior and Riverpod 3 automatic retry handling.

### Version Detection

Codegen chooses Riverpod 2 vs 3 output by reading sibling package pubspecs
(from the server package directory):

1. `*_flutter` — `flutter_riverpod` / `riverpod`
2. `*_client` — `riverpod`
3. server pubspec (fallback)

If none declare a Riverpod constraint, the generator assumes Riverpod 3.

You do **not** need `riverpod` on the server package for version detection when
the Flutter or client package already declares it.

## You Write

Annotate your Serverpod endpoint methods:

```dart
import 'package:riverpod_for_serverpod_annotation/riverpod_for_serverpod_annotation.dart';
import 'package:serverpod/serverpod.dart';

class AdminEndpoint extends Endpoint {
  @CacheTtl(Duration(minutes: 3))
  Future<List<Role>> listRoles(Session session) async {
    return Role.db.find(session);
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
    // Update users, then refresh generated providers from the client.
  }
}
```

## Generated

The generator creates a typed endpoint manifest, read providers, mutation
commands/controllers, cache integration, and invalidation helpers. Generated
code should be regenerated instead of edited directly.

<details>
<summary>Show representative generated output</summary>

```dart
const generatedEndpointManifest = EndpointManifest(
  endpoints: [
    EndpointInfo(
      name: 'AdminEndpoint',
      methods: [
        MethodInfo(name: 'listRoles', /* generated metadata */),
        MethodInfo(
          name: 'updateUsersRole',
          mutationCommand: MutationCommandInfo(
            affects: 'User',
            retry: RetryPolicy.none,
          ),
          /* generated parameter and invalidation metadata */
        ),
      ],
    ),
  ],
);

abstract class RefAdminEndpoint {
  static final refUpdateAll = NotifierProvider<Counter, int>(Counter.new);

  static final listRoles = FutureProvider.autoDispose<List<Role>>(
    (ref) async {
      ref
        ..watch(refUpdateAllGeneratedProviders)
        ..watch(refUpdateAll);

      final result = await ref.watch(clientProvider).admin.listRoles();
      ref.cacheFor(const Duration(minutes: 3));
      return result;
    },
    retry: _noProviderRetry,
  );

  static void updateAll(Reader read) {
    read(refUpdateAll.notifier).updateAll();
  }

  static void invalidateAfterUpdateUsersRole(
    Reader read,
    ProviderInvalidator invalidate,
  ) {
    RefAdminEndpoint.updateAll(read);
    RefUserEndpoint.updateAll(read);
  }
}

abstract final class RefAdminEndpointCommands {
  static Future<void> updateUsersRole(
    Reader read,
    ProviderInvalidator invalidate,
    List<int> userIds,
    String roleName,
  ) async {
    await read(clientProvider).admin.updateUsersRole(userIds, roleName);
    RefAdminEndpoint.invalidateAfterUpdateUsersRole(read, invalidate);
  }
}

final adminMutationControllerProvider =
    AsyncNotifierProvider<AdminMutationController, void>(
  AdminMutationController.new,
);

final class AdminMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateUsersRole(
    List<int> userIds,
    String roleName,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await RefAdminEndpointCommands.updateUsersRole(
        ref.read,
        ref.invalidate,
        userIds,
        roleName,
      );
    });
  }
}
```

The full generated file also includes shared client/provider plumbing,
compatibility helpers, diagnostics metadata, and retry/warning integration.

</details>

## Install

Serverpod projects are three packages. Dependencies belong in different places:

| Package | Role |
|---|---|
| `*_server` | Annotate endpoints; run `build_runner` + copy script |
| `*_client` | Owns generated `ref_endpoints.dart` (Riverpod code compiles here) |
| `*_flutter` | App UI; `flutter_riverpod` + optional Hive storage |

### 1. Server (`*_server`)

```yaml
dependencies:
  riverpod_for_serverpod_annotation: ^3.0.0

dev_dependencies:
  build_runner: ^2.5.0
  riverpod_for_serverpod_generator: ^3.0.0
```

Keep Serverpod’s usual analyzer exclude so the intermediate generated file is
not type-checked as server code:

```yaml
analyzer:
  exclude:
    - lib/src/generated/**
```

Optional Serverpod script:

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

### 2. Client (`*_client`)

```yaml
dependencies:
  riverpod: ^3.0.0
  riverpod_for_serverpod_runtime: ^3.0.0
  serverpod_auth_client: 3.4.4 # match your serverpod_client version
  serverpod_client: 3.4.4
```

Export the copied file from the client library:

```dart
export 'ref_endpoints.dart';
```

### 3. Flutter app (`*_flutter`)

```yaml
dependencies:
  flutter_riverpod: ^3.0.0
  your_project_client:
    path: ../your_project_client
  # optional persistent cache:
  # riverpod_for_serverpod_hive_storage: ^3.0.0
```

Do **not** put `riverpod_for_serverpod_runtime`, Hive storage, or
`flutter_riverpod` on the server. Do **not** put the generator on the client
or Flutter package (`auto_apply: dependents` would try to run it there).

### Generate

From the server package:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run riverpod_for_serverpod_generator:copy_ref_endpoints
# or: serverpod run ref_endpoints
```

`copy_ref_endpoints` copies `lib/src/generated/ref_endpoints.dart` into the
sibling `*_client` package as `lib/ref_endpoints.dart`, and by default **fills
missing trio dependencies** (annotation/generator on server, riverpod+runtime
on client, `flutter_riverpod` on Flutter) plus a client `export` when needed.
Pass `--no-ensure-deps` to only copy.

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

## Client Usage

Override `clientProvider` with your Serverpod client:

```dart
final container = ProviderContainer(
  overrides: [
    clientProvider.overrideWithValue(client),
  ],
);
```

Watch generated providers:

```dart
final roles = ref.watch(RefAdminEndpoint.listRoles);
```

**[@MutationCommand](riverpod_for_serverpod_annotation)** methods no longer get `FutureProvider` fields (mutations are not passive reads). Call the generated command instead:

```dart
await RefAdminEndpointCommands.updateUserRole(
  ref.read,
  ref.invalidate,
  userId,
  roleName,
);
```

The generator also emits an `AsyncNotifier<void>` mutation controller per
endpoint with mutation commands, so UI code can watch loading/error state:

```dart
await ref
    .read(adminMutationControllerProvider.notifier)
    .updateUserRole(userId, roleName);
```

On connection-like failures, the command can enqueue work on `mutationRetryQueueProvider` (from `riverpod_for_serverpod_runtime`) when the mutation is **idempotent** and retry is enabled.

**[@CachedQuery](riverpod_for_serverpod_annotation)** reads use generated cache-aware
providers. Background-refresh queries use stale-while-revalidate
`AsyncNotifier` providers; other cached queries use `FutureProvider`. Refresh
failures are aggregated through `refreshWarningProvider`.

Generated cached queries read from `generatedCacheStorageProvider`, or
`generatedSecureCacheStorageProvider` when `secure: true`. The runtime exports
memory-backed defaults so generated code works in tests, but production apps
should usually override them with persistent storage:

```dart
final container = ProviderContainer(
  overrides: [
    generatedCacheStorageProvider.overrideWith((ref) async {
      return await openHiveGeneratedCacheStorage();
    }),
  ],
);
```

For user-scoped secure cache, wrap the persistent storage and clear the same
namespace on logout:

```dart
final keyValue = await openHiveGeneratedKeyValueStorage(
  boxName: 'generated_secure_cache',
  encryptionKey: key,
);

final secureStorage = NamespacedGeneratedCacheStorage(
  inner: JsonGeneratedCacheStorage(keyValue),
  namespace: 'user/$userId',
);

await clearGeneratedCacheNamespace(
  storage: keyValue,
  namespace: 'user/$userId',
);
```

When calling the Serverpod client directly instead of a generated mutation
command, call the generated invalidation hook after success. The hook includes
the entries from `MutationCommand.invalidate`:

```dart
await client.admin.updateUsersRole(userIds, roleName);
RefAdminEndpoint.invalidateAfterUpdateUsersRole(ref.read, ref.invalidate);
```

## Packages

See package-level documentation:

- [Riverpod 2 and 3 compatibility](riverpod_2_and_3_compatibility.md)
- [`riverpod_for_serverpod_annotation`](riverpod_for_serverpod_annotation/README.md)
- [`riverpod_for_serverpod_runtime`](riverpod_for_serverpod_runtime/README.md)
- [`riverpod_for_serverpod_hive_storage`](riverpod_for_serverpod_hive_storage/README.md)
- [`riverpod_for_serverpod_generator`](riverpod_for_serverpod_generator/README.md)

## License

MIT. See [`LICENSE`](LICENSE).
