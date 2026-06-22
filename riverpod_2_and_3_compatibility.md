# Riverpod 2 and 3 Compatibility

The `3.x` package line targets Riverpod `3.x`. For Riverpod `2.6.x`, use the
`2.6.x` package line or branch.

The generator inspects the host package's `pubspec.yaml` when emitting
compatibility-sensitive code.

## Ref.cacheFor

When `pubspec.yaml` allows Riverpod `3.x`, generated `Ref.cacheFor` code checks
`Ref.mounted` before calling `keepAlive` and `onDispose`:

```dart
extension RefCacheForExtension on Ref {
  void cacheFor(Duration duration) {
    if (!mounted) return;
    final link = keepAlive();
    final timer = Timer(duration, link.close);

    onDispose(timer.cancel);
  }
}
```

When all listed `riverpod` and `flutter_riverpod` constraints exclude Riverpod
`3.x`, the generator emits a `try` / `on StateError` workaround because Riverpod
2 does not expose `Ref.mounted`.

Generated providers call `cacheFor` only after an endpoint request succeeds.
Failed requests are therefore not kept alive as successful cached values.

## Generated Provider Example

```dart
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

## Riverpod 3 Automatic Retry

Riverpod 3 automatically retries failed providers by default. Generated endpoint
providers disable that behavior with:

```dart
retry: _noProviderRetry
```

Generated mutation commands and the runtime retry queue provide explicit retry
behavior for eligible idempotent mutations.
