import 'dart:io';

import 'package:build_config/build_config.dart' show InputSet;
import 'package:build_runner/build_runner.dart' as br;
import 'package:build_runner_core/build_runner_core.dart' as core;
import 'package:riverpod_for_serverpod_generator/builder.dart' as riverpod_for_serverpod_generator;

Future<void> main(List<String> args) async {
  final builders = <core.BuilderApplication>[
    core.apply(
      'your_pkg:ref_endpoint_builder',
      [riverpod_for_serverpod_generator.refEndpointBuilder],
      core.toRoot(),
      hideOutput: false,
      defaultGenerateFor: const InputSet(include: ['pubspec.yaml']),
    ),
  ];

  final code = await br.run(args, builders);
  exit(code);
}
