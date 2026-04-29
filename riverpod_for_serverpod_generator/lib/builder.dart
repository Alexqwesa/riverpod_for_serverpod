import 'package:build/build.dart';
import 'package:riverpod_for_serverpod_generator/src/generator.dart';

/// Exposes a Builder that will be run by build_runner.
Builder refEndpointBuilder(BuilderOptions options) =>
    RefEndpointBuilder();
