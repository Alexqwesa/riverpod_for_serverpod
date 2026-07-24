## 3.0.0

- Migrated the generated provider output to the Riverpod `3.x` release line.
- Disabled Riverpod 3's default automatic retry for generated endpoint providers with `retry: _noProviderRetry`.
- Generated `@CachedQuery` providers with `GeneratedEntityCache` (SWR or FutureProvider).
- Generated `@MutationCommand` helpers, mutation controllers, connection retry queue wiring, and validation.
- Mutation commands take `Reader read, ProviderInvalidator invalidate` so apps pass `ref.read, ref.invalidate` without baking `Ref` into the public command API.
- Typed `Invalidate.provider` / `providerFamily` hooks call `…Invalidate(invalidate, …)` correctly.
- `CachedQuery.ttl` drives both entity-index TTL and `ref.cacheFor`.
- Sibling-package Riverpod version detection (`*_flutter` → `*_client` → server).
- `copy_ref_endpoints` can fill missing trio dependencies by default.
- Generated `Ref.cacheFor`: Riverpod 3+ uses `if (!mounted) return`; Riverpod 2-target pubspecs emit a `StateError` try/catch (no `Ref.mounted`).
- Documented that Riverpod `2.6.x` users should stay on the `2.6.x` package line/branch.

## 2.6.0

- Aligned the package version with the supported Riverpod `2.6.x` line.
- Documented that Riverpod 3 support will live on a separate future branch/release line.
- Kept generated provider output targeting Riverpod 2.6 APIs.

## 1.0.1

- Updated the generator internals for newer analyzer and build_runner APIs used with Serverpod 3.4.4.
- No intended generated API redesign; this release is a compatibility fix so existing `ref_endpoints` generation can continue to work.

## 1.0.0

- Initial version.
