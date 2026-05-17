# Selector demo (Serverpod Mini + Riverpod generator)

This example uses **Serverpod Mini** (no PostgreSQL) with in-memory data, `riverpod_for_serverpod_*` path dependencies from this monorepo, and [`generic_search_selector`](https://github.com/Alexqwesa/generic_search_selector) pickers in Flutter.

## Prerequisites

- **Dart / Flutter**: Dart SDK **^3.10.1** (required by `generic_search_selector`). Use a Flutter SDK whose Dart version satisfies that constraint.
- **Serverpod CLI** for `serverpod generate` (already used when this project was scaffolded).

## Workspace layout

- `selector_demo_server` — Mini server, protocol models, endpoints, `build_runner` output at `lib/src/generated/ref_endpoints.dart`.
- `selector_demo_client` — generated Serverpod client; **`lib/ref_endpoints.dart` is copied from the server** after codegen (do not edit by hand).
- `selector_demo_flutter` — `flutter_riverpod` app watching generated providers.

From this directory (`example/selector_demo`), run:

```bash
dart pub get
```

## Code generation

After changing endpoints or `*.spy.yaml` models:

```bash
cd selector_demo_server
serverpod generate
dart run build_runner build --delete-conflicting-outputs
dart run riverpod_for_serverpod_generator:copy_ref_endpoints
```

Or use the Serverpod script (from `selector_demo_server`):

```bash
serverpod run ref_endpoints
```

`copy_ref_endpoints` writes `../selector_demo_client/lib/ref_endpoints.dart`.

## Run the Mini server

```bash
cd selector_demo_server
dart run bin/main.dart
```

Default URL: `http://localhost:8080/`.

## Run the Flutter app

In another terminal:

```bash
cd selector_demo_flutter
flutter run --dart-define=SERVER_URL=http://localhost:8080/
```

On a physical device, set `SERVER_URL` to your machine’s LAN IP (same pattern as the stock Serverpod Flutter template).

## Integration test (smoke)

1. Start the server (see above).
2. Run:

```bash
cd selector_demo_flutter
flutter test integration_test/selector_demo_smoke_test.dart -d windows
```

Use `-d <deviceId>` if multiple devices are connected (`flutter devices`). On CI, pick Chrome or Linux/Windows explicitly.

The smoke test boots the app and looks for the app title. Full picker flows assume a reachable server.

## Server tests

```bash
cd selector_demo_server
dart test test/integration/selector_endpoint_test.dart
```
