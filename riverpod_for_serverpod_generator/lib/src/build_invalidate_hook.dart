import 'package:code_builder/code_builder.dart';
import 'package:recase/recase.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';

/// Minimal endpoint shape needed to resolve typed invalidation targets.
class InvalidateHookEndpoint {
  const InvalidateHookEndpoint(this.name, this.methods);

  final String name;
  final List<MyMethodMeta> methods;
}

/// Builds `invalidateAfter*` for one endpoint method.
Method buildInvalidateHookMethod({
  required String currentEndpoint,
  required MyMethodMeta method,
  required List<InvalidateHookEndpoint> endpoints,
}) {
  final methodName = 'invalidateAfter${ReCase(method.name).pascalCase}';
  final endpointTargets = <String>{
    if (method.includeSelfInHook) 'Ref$currentEndpoint',
    ...method.invalidateTargets,
  };

  final endpointByName = {
    for (final endpoint in endpoints) endpoint.name: endpoint,
  };
  final methodArgs = {
    for (final p in method.positionalParams) p.name: p,
    for (final p in method.namedParams) p.name: p,
  };
  final hookArgs = <String, MyParamMeta>{};
  for (final invalidate in method.mutationCommand?.invalidate ?? const []) {
    final argFrom = invalidate.argFrom;
    if (argFrom == null) continue;
    final arg = methodArgs[argFrom];
    if (arg != null) hookArgs[argFrom] = arg;
  }

  final body = StringBuffer();
  final emitted = <String>{};
  for (final target in endpointTargets) {
    if (!emitted.add('$target.updateAll(read);')) continue;
    body.writeln('$target.updateAll(read);');
  }
  for (final line in buildTypedInvalidationLines(
    currentEndpoint: currentEndpoint,
    method: method,
    endpointByName: endpointByName,
    methodArgs: methodArgs,
  )) {
    if (emitted.add(line)) body.writeln(line);
  }

  return Method((mb) {
    mb
      ..name = methodName
      ..static = true
      ..returns = refer('void')
      ..requiredParameters.add(
        Parameter(
          (p) => p
            ..name = 'read'
            ..type = refer('Reader'),
        ),
      )
      ..requiredParameters.add(
        Parameter(
          (p) => p
            ..name = 'invalidate'
            ..type = refer('ProviderInvalidator'),
        ),
      );

    for (final arg in hookArgs.values) {
      mb.requiredParameters.add(
        Parameter(
          (p) => p
            ..name = arg.name
            ..type = refer(arg.type),
        ),
      );
    }

    mb.body = Code(body.toString());
  });
}

/// Emits the source of [buildInvalidateHookMethod] for tests/assertions.
String buildInvalidateHookSource({
  required String currentEndpoint,
  required MyMethodMeta method,
  required List<InvalidateHookEndpoint> endpoints,
}) {
  return buildInvalidateHookMethod(
    currentEndpoint: currentEndpoint,
    method: method,
    endpoints: endpoints,
  ).accept(DartEmitter()).toString();
}

/// Typed `Invalidate.*` lines for one mutation (uses `invalidate`, not `read`).
Iterable<String> buildTypedInvalidationLines({
  required String currentEndpoint,
  required MyMethodMeta method,
  required Map<String, InvalidateHookEndpoint> endpointByName,
  required Map<String, MyParamMeta> methodArgs,
}) sync* {
  final invalidations = method.mutationCommand?.invalidate ?? const [];
  for (final invalidate in invalidations) {
    final endpointClass =
        targetEndpointClass(invalidate.endpoint, currentEndpoint);
    final refClass = 'Ref$endpointClass';
    switch (invalidate.kind) {
      case 'self':
      case 'endpoint':
        yield '$refClass.updateAll(read);';
      case 'provider':
        final provider = invalidate.provider;
        if (provider == null || provider.isEmpty) continue;
        final targetMethod = findEndpointMethod(
          endpointByName[endpointClass],
          provider,
        );
        final exactArg = exactInvalidationArgExpression(
          invalidate: invalidate,
          targetMethod: targetMethod,
          methodArgs: methodArgs,
        );
        if (exactArg == null) {
          yield '$refClass.${provider}InvalidateAll(invalidate);';
        } else {
          yield '$refClass.${provider}Invalidate(invalidate, $exactArg);';
        }
    }
  }
}

MyMethodMeta? findEndpointMethod(
  InvalidateHookEndpoint? endpoint,
  String methodName,
) {
  if (endpoint == null) return null;
  for (final method in endpoint.methods) {
    if (method.name == methodName) return method;
  }
  return null;
}

String targetEndpointClass(String? endpoint, String currentEndpoint) {
  final raw = endpoint?.trim();
  if (raw == null || raw.isEmpty) return currentEndpoint;
  final noPrefix = raw.startsWith('Ref') ? raw.substring(3) : raw;
  final className =
      noPrefix.contains('.') ? noPrefix.split('.').last : noPrefix;
  return className.endsWith('Endpoint') ? className : '${className}Endpoint';
}

String? exactInvalidationArgExpression({
  required InvalidateMeta invalidate,
  required MyMethodMeta? targetMethod,
  required Map<String, MyParamMeta> methodArgs,
}) {
  final argFrom = invalidate.argFrom;
  if (argFrom == null || !methodArgs.containsKey(argFrom)) return null;
  if (targetMethod == null) return argFrom;
  final targetArgCount =
      targetMethod.positionalParams.length + targetMethod.namedParams.length;
  return targetArgCount == 1 ? argFrom : null;
}
