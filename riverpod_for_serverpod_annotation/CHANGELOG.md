## 3.0.0

- Aligned the package version with the supported Riverpod `3.x` generator line.
- Documented that Riverpod `2.6.x` users should stay on the `2.6.x` package line/branch.
- Added `@CachedQuery`, `@MutationCommand`, `Invalidate.*`, retry/refetch/optimistic
  policies, and `@ValidateString` / `@ValidateNumber` / `@ValidateList`.
- `@CachedQuery.ttl` drives both entity-index TTL and Riverpod `cacheFor`;
  `@CacheTtl` is for plain (non-cached-query) reads.

## 2.6.0

- Aligned the package version with the supported Riverpod `2.6.x` line.
- Riverpod 3 support will live on a separate future branch/release line.

## 1.0.0

- Initial version.
