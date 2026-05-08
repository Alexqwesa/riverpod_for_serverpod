import 'dart:convert';

import 'package:recase/recase.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';

/// Emits `abstract final class Ref…Commands { … }` or empty when there are no
/// [@MutationCommand] methods.
String buildMutationCommandsClass({
  required String endpointClassName,
  required String clientField,
  required List<MyMethodMeta> mutationMethods,
}) {
  if (mutationMethods.isEmpty) return '';

  final buf = StringBuffer();
  buf.writeln('abstract final class Ref${endpointClassName}Commands {');
  for (final method in mutationMethods) {
    buf.writeln(buildMutationCommandMethod(
      endpointClassName: endpointClassName,
      clientField: clientField,
      method: method,
    ));
  }
  buf.writeln('}');
  return buf.toString();
}

String buildMutationCommandMethod({
  required String endpointClassName,
  required String clientField,
  required MyMethodMeta method,
}) {
  final meta = method.mutationCommand!;
  final hook = 'invalidateAfter${ReCase(method.name).pascalCase}';
  final refClass = 'Ref$endpointClassName';
  final retryEnabled = meta.retry != 'RetryPolicy.none';
  final queueId = _mutationQueueIdExpression(endpointClassName, method, meta);
  final timeoutSuffix =
      method.timeout != null ? '.timeout(const ${method.timeout})' : '';

  final readCall =
      'read(clientProvider).$clientField.${method.name}(${_mutationCallArgs(method)})$timeoutSuffix';

  final buffer = StringBuffer();
  buffer.write('  static ${method.returnType} ${method.name}(');
  buffer.write('Reader read');
  for (final p in method.positionalParams) {
    buffer.write(', ${p.type} ${p.name}');
  }
  for (final p in method.namedParams) {
    buffer.write(', ${p.type} ${p.name}');
  }
  buffer.writeln(') async {');
  _writeMutationCommandValidations(buffer, method, indent: '    ');
  buffer.writeln('    try {');

  if (method.unwrappedReturnType == 'void') {
    buffer.writeln('      await $readCall;');
    buffer.writeln('      $refClass.$hook(read);');
  } else {
    buffer.writeln('      final result = await $readCall;');
    buffer.writeln('      $refClass.$hook(read);');
    buffer.writeln('      return result;');
  }

  buffer.writeln(r'    } catch (e, st) {');
  buffer.writeln('      if (mutationFailureShouldEnqueue(');
  buffer.writeln('            error: e,');
  buffer.writeln('            idempotent: ${meta.idempotent},');
  buffer.writeln('            retryEnabled: $retryEnabled,');
  buffer.writeln('          )) {');
  buffer.writeln('        read(mutationRetryQueueProvider).schedule(');
  buffer.writeln('          id: $queueId,');
  buffer.writeln('          idempotent: ${meta.idempotent},');
  buffer.writeln("          label: r'${method.name}',");
  buffer.writeln('          run: () async {');
  _writeMutationCommandValidations(buffer, method, indent: '            ');
  if (method.unwrappedReturnType == 'void') {
    buffer.writeln('            await $readCall;');
  } else {
    buffer.writeln('            await $readCall;');
  }
  buffer.writeln('            $refClass.$hook(read);');
  buffer.writeln('          },');
  buffer.writeln('        );');
  buffer.writeln('      }');
  buffer.writeln('      rethrow;');
  buffer.writeln('    }');
  buffer.writeln('  }');
  return buffer.toString();
}

String _mutationCallArgs(MyMethodMeta method) {
  final parts = <String>[
    ...method.positionalParams.map((p) => p.name),
    ...method.namedParams.map((p) => '${p.name}: ${p.name}'),
  ];
  return parts.join(', ');
}

String _mutationQueueIdExpression(
  String endpointClassName,
  MyMethodMeta method,
  MutationCommandMeta meta,
) {
  final idArg = meta.idArg;
  if (idArg != null &&
      (method.positionalParams.any((p) => p.name == idArg) ||
          method.namedParams.any((p) => p.name == idArg))) {
    return "'$endpointClassName.${method.name}.\$$idArg'";
  }
  return "'$endpointClassName.${method.name}'";
}

void _writeMutationCommandValidations(
  StringBuffer buffer,
  MyMethodMeta method, {
  required String indent,
}) {
  for (final v in method.validateStrings) {
    buffer.writeln(
      "${indent}validateGeneratedString(r'${v.arg}', ${v.arg}, notEmpty: ${v.notEmpty}, minLength: ${_emitNullableInt(v.minLength)}, maxLength: ${_emitNullableInt(v.maxLength)}, pattern: ${_emitPatternArg(v.pattern)});",
    );
  }
  for (final v in method.validateNumbers) {
    buffer.writeln(
      "${indent}validateGeneratedNumber(r'${v.arg}', ${v.arg}, min: ${_emitNullableNum(v.min)}, max: ${_emitNullableNum(v.max)});",
    );
  }
  for (final v in method.validateLists) {
    buffer.writeln(
      "${indent}validateGeneratedIterable(r'${v.arg}', ${v.arg}, notEmpty: ${v.notEmpty}, minLength: ${_emitNullableInt(v.minLength)}, maxLength: ${_emitNullableInt(v.maxLength)});",
    );
  }
}

String _emitNullableInt(int? v) => v == null ? 'null' : '$v';

String _emitNullableNum(num? v) {
  if (v == null) return 'null';
  return v is int ? '$v' : v.toString();
}

String _emitPatternArg(String? pattern) =>
    pattern == null ? 'null' : jsonEncode(pattern);
