import 'package:serverpod/serverpod.dart';

import 'src/generated/protocol.dart';
import 'src/generated/endpoints.dart';
import 'src/selector/selector_repository.dart';

/// The starting point of the Serverpod server.
void run(List<String> args) async {
  SelectorRepository.instance.seed();

  // Initialize Serverpod and connect it with your generated code.
  final pod = Serverpod(args, Protocol(), Endpoints());

  // Start the server.
  await pod.start();
}
