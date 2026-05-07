# riverpod_for_serverpod

Generate Riverpod providers for Serverpod endpoint methods.

This repository contains two Dart packages:

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

  @RefInvalidate(['UserEndpoint'])
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

The generator creates Riverpod providers and invalidation helpers. Generated code is not hand-written and should be regenerated instead of edited directly.

```dart
extension RefCacheForExtension on Ref {
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);

    onDispose(timer.cancel);
  }
}

abstract class RefAdminEndpoint {
  static final listRoles = FutureProvider.autoDispose<List<Role>>((ref) async {
    ref
      ..watch(refUpdateAllGeneratedProviders)
      ..watch(refUpdateAll);

    final result = await ref.watch(clientProvider).admin.listRoles();

    ref.cacheFor(const Duration(minutes: 3));

    return result;
  });

  static void invalidateAfterUpdateUsersRole(Reader read) {
    RefAdminEndpoint.updateAll(read);
    RefUserEndpoint.updateAll(read);
  }
}
```

`cacheFor` is called after the endpoint call succeeds, so failed requests are not kept alive as successful cached values.

Generated endpoint providers also disable Riverpod 3's default automatic retry
with `retry: _noProviderRetry`; explicit offline/retry behavior belongs in the
future generated retry queue.

## Install

In the Serverpod server package:

```yaml
dependencies:
  riverpod_for_serverpod_annotation: ^3.0.0
  riverpod_for_serverpod_runtime: ^3.0.0
  riverpod_for_serverpod_hive_storage: ^3.0.0

dev_dependencies:
  build_runner: ^2.5.0
  riverpod_for_serverpod_generator: ^3.0.0
```

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

To copy the generated file into the matching client package:

```bash
dart run riverpod_for_serverpod_generator:copy_ref_endpoints
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

After successful mutations, call the generated invalidation hook:

```dart
await client.admin.updateUsersRole(userIds, roleName);
RefAdminEndpoint.invalidateAfterUpdateUsersRole(ref.read);
```

## Packages

See package-level documentation:

- [`riverpod_for_serverpod_annotation`](riverpod_for_serverpod_annotation/README.md)
- [`riverpod_for_serverpod_runtime`](riverpod_for_serverpod_runtime/README.md)
- [`riverpod_for_serverpod_hive_storage`](riverpod_for_serverpod_hive_storage/README.md)
- [`riverpod_for_serverpod_generator`](riverpod_for_serverpod_generator/README.md)

## License

MIT. See [`LICENSE`](LICENSE).
