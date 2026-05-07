## 3.0.0

- Migrated the generated provider output to the Riverpod `3.x` release line.
- Disabled Riverpod 3's default automatic retry for generated endpoint providers with `retry: _noProviderRetry` so generation preserves explicit endpoint-call semantics until the planned retry queue is implemented.
- Added parser metadata for future `@CachedQuery`, `@MutationCommand`, `Invalidate.*`, and validation annotations.
- Added an internal endpoint manifest builder that scans Serverpod endpoint source and attaches query, mutation, invalidation, and validation metadata without changing generated provider output yet.
- Added `generatedEndpointManifest` output as a const map in the generated Dart file for debugging and future runtime/cache generation.
- Added manifest diagnostics for conflicting annotations, unsupported cached return types, invalid cache settings, unsafe retry metadata, and bool-return mutation refetch gaps.
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
