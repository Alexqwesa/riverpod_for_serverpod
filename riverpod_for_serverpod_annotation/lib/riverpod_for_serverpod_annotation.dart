/// Annotations for marking Serverpod endpoints so
/// `riverpod_for_serverpod_generator` can emit Riverpod providers, mutation
/// helpers, caches, and an endpoint manifest.
///
/// Apply annotations only to Serverpod endpoint **methods** whose first
/// parameter is `Session session` (or to entire endpoint classes with
/// [DoNotGenerate], which skips generation for that unit). Each public type
/// below documents what the generator reads at build time. Most annotation
/// fields affect emitted Dart (providers, commands, cache behavior); the
/// endpoint manifest duplicates several of them for tooling and introspection.
///
/// ## Regenerate after changes
///
/// From your Serverpod **server** package (where the generator runs):
///
/// ```bash
/// dart run build_runner build --delete-conflicting-outputs
/// ```
///
/// Output is written under `lib/src/generated/` (notably `ref_endpoints.dart`);
/// many projects copy that file into the matching `*_client` package. See the
/// root `README.md` of this repository for install, copy scripts, and usage.
library;

export 'src/annotation.dart';
