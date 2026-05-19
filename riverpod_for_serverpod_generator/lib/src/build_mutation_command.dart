import 'dart:convert';

import 'package:recase/recase.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';

/// Emits `abstract final class Ref…Commands { … }` or empty when there are no
/// [@MutationCommand] methods.
String buildMutationCommandsClass({
  required String endpointClassName,
  required String clientField,
  required List<MyMethodMeta> mutationMethods,
  Map<String, EntityCacheTemplate> entityCacheTemplates = const {},
  Map<String, String> methodToClientField = const {},
}) {
  if (mutationMethods.isEmpty) return '';

  final buf = StringBuffer();
  buf.writeln('abstract final class Ref${endpointClassName}Commands {');
  for (final method in mutationMethods) {
    buf.writeln(buildMutationCommandMethod(
      endpointClassName: endpointClassName,
      clientField: clientField,
      method: method,
      entityCacheTemplates: entityCacheTemplates,
      methodToClientField: methodToClientField,
    ));
  }
  buf.writeln('}');
  return buf.toString();
}

/// Emits an optional `AsyncNotifier<void>` controller for [@MutationCommand]
/// methods. The controller delegates to the static command helpers and exposes
/// loading/error state to UI code.
String buildMutationControllerSource({
  required String endpointClassName,
  required List<MyMethodMeta> mutationMethods,
}) {
  if (mutationMethods.isEmpty) return '';

  final baseName = endpointClassName.replaceAll(RegExp(r'Endpoint$'), '');
  final controllerName = '${ReCase(baseName).pascalCase}MutationController';
  final providerName =
      '${ReCase(baseName).camelCase}MutationControllerProvider';
  final commandsClass = 'Ref${endpointClassName}Commands';

  final buf = StringBuffer();
  buf.writeln('final $providerName =');
  buf.writeln('    AsyncNotifierProvider<$controllerName, void>(');
  buf.writeln('  $controllerName.new,');
  buf.writeln(');');
  buf.writeln();
  buf.writeln('final class $controllerName extends AsyncNotifier<void> {');
  buf.writeln('  @override');
  buf.writeln('  Future<void> build() async {}');
  buf.writeln();
  for (final method in mutationMethods) {
    buf.writeln(_buildMutationControllerMethod(
      commandsClass: commandsClass,
      method: method,
    ));
  }
  buf.writeln('}');
  return buf.toString();
}

String _buildMutationControllerMethod({
  required String commandsClass,
  required MyMethodMeta method,
}) {
  final buf = StringBuffer();
  buf.write('  Future<void> ${method.name}(');
  var needsComma = false;
  for (final p in method.positionalParams) {
    if (needsComma) buf.write(', ');
    buf.write('${p.type} ${p.name}');
    needsComma = true;
  }
  for (final p in method.namedParams) {
    if (needsComma) buf.write(', ');
    buf.write('${p.type} ${p.name}');
    needsComma = true;
  }
  buf.writeln(') async {');
  buf.writeln('    state = const AsyncLoading();');
  buf.writeln('    state = await AsyncValue.guard(() async {');
  buf.write('      await $commandsClass.${method.name}(ref.read');
  for (final p in method.positionalParams) {
    buf.write(', ${p.name}');
  }
  for (final p in method.namedParams) {
    buf.write(', ${p.name}');
  }
  buf.writeln(');');
  buf.writeln('    });');
  buf.writeln('  }');
  return buf.toString();
}

String _mutationEntityStorageProviderName(EntityCacheTemplate t) =>
    t.secure
        ? 'generatedSecureCacheStorageProvider'
        : 'generatedCacheStorageProvider';

String? _mutationIdExpression(MutationCommandMeta meta, MyMethodMeta method) {
  final id = meta.idArg;
  if (id == null) return null;
  if (method.positionalParams.any((p) => p.name == id) ||
      method.namedParams.any((p) => p.name == id)) {
    return id;
  }
  return null;
}

bool _returnTypeMatchesEntityMerge(String unwrapped, String elementType) {
  final u = unwrapped.trim();
  final base = u.endsWith('?') ? u.substring(0, u.length - 1).trim() : u;
  return base == elementType.trim();
}

String? _resolvedByIdMethodName(
  MutationCommandMeta meta,
  EntityCacheTemplate template,
) =>
    meta.byIdMethod ?? template.byIdMethod;

String? _resolvedByIdClientField(
  MutationCommandMeta meta,
  EntityCacheTemplate template,
  Map<String, String> methodToClientField,
) {
  final name = _resolvedByIdMethodName(meta, template);
  if (name == null) return null;
  return methodToClientField[name];
}

/// Prefer an explicit `byId` RPC before writing the entity cache (ignore inline
/// mutation result for that write).
bool _cacheMergePolicyPrefersRefetchById(EntityCacheTemplate template) =>
    template.mergePolicy == 'CacheMergePolicy.refetchById';

/// `replaceEntity` merge policy (same as `CachedQuery` default).
bool _cacheMergePolicyPrefersMutationResponse(EntityCacheTemplate template) =>
    template.mergePolicy == 'CacheMergePolicy.replaceEntity';

bool _needsMutationEntityCacheOpen({
  required MutationCommandMeta meta,
  required MyMethodMeta method,
  required EntityCacheTemplate? template,
  required Map<String, String> methodToClientField,
}) {
  if (template == null) return false;
  final idExpr = _mutationIdExpression(meta, method);
  if (meta.optimistic == 'OptimisticPolicy.patchLocalCache' &&
      idExpr != null) {
    return true;
  }
  if (meta.refetch == 'RefetchPolicy.mergeReturnedEntity' &&
      _returnTypeMatchesEntityMerge(
        method.unwrappedReturnType,
        template.elementType,
      )) {
    return true;
  }
  if (meta.refetch == 'RefetchPolicy.byId' && idExpr != null) {
    if (_cacheMergePolicyPrefersMutationResponse(template) &&
        _returnTypeMatchesEntityMerge(
          method.unwrappedReturnType,
          template.elementType,
        ) &&
        method.unwrappedReturnType != 'void') {
      return true;
    }
    final cf = _resolvedByIdClientField(meta, template, methodToClientField);
    final byId = _resolvedByIdMethodName(meta, template);
    return cf != null && byId != null;
  }
  return false;
}

/// After a successful RPC: merge/refetched entity updates or clear pendingSync.
///
/// [EntityCacheTemplate.mergePolicy] selects `putOne(result)` vs an extra
/// `byId` round-trip when paired with [MutationCommand.refetch]: only the
/// `refetchById` policy forces the extra fetch; `replaceEntity` (default on
/// `CachedQuery`) prefers the mutation response when types align.
String _mutationPostSuccessEntityCacheLines({
  required MutationCommandMeta meta,
  required MyMethodMeta method,
  required EntityCacheTemplate template,
  required Map<String, String> methodToClientField,
  required String indent,
}) {
  final idExpr = _mutationIdExpression(meta, method);
  final byIdName = _resolvedByIdMethodName(meta, template);
  final byIdCf = _resolvedByIdClientField(meta, template, methodToClientField);
  final canRefetchById =
      idExpr != null && byIdName != null && byIdCf != null;
  final returnMatches = _returnTypeMatchesEntityMerge(
    method.unwrappedReturnType,
    template.elementType,
  );

  final buf = StringBuffer();

  void writePutResult(String expr) {
    final trimmed = method.unwrappedReturnType.trim();
    final nullableResult = trimmed.endsWith('?');
    if (nullableResult) {
      buf.writeln('${indent}if ($expr != null) {');
      buf.writeln(
        '${indent}  await __mutEntityCache.putOne($expr, pendingSync: false);',
      );
      buf.writeln('${indent}}');
    } else {
      buf.writeln(
        '${indent}await __mutEntityCache.putOne($expr, pendingSync: false);',
      );
    }
  }

  void writeRefetchById() {
    buf.writeln(
      '${indent}final __mutRefetched = await read(clientProvider).$byIdCf.$byIdName($idExpr);',
    );
    buf.writeln('${indent}if (__mutRefetched != null) {');
    buf.writeln(
      '${indent}  await __mutEntityCache.putOne(__mutRefetched, pendingSync: false);',
    );
    buf.writeln('${indent}}');
  }

  if (meta.refetch == 'RefetchPolicy.mergeReturnedEntity' && returnMatches) {
    if (_cacheMergePolicyPrefersRefetchById(template) && canRefetchById) {
      writeRefetchById();
    } else {
      writePutResult('result');
    }
  } else if (meta.refetch == 'RefetchPolicy.byId' && idExpr != null) {
    final prefersReturned = _cacheMergePolicyPrefersMutationResponse(template) &&
        returnMatches &&
        method.unwrappedReturnType != 'void';
    if (prefersReturned) {
      writePutResult('result');
    } else if (byIdName != null && byIdCf != null) {
      writeRefetchById();
    }
  } else if (meta.optimistic == 'OptimisticPolicy.patchLocalCache' &&
      idExpr != null) {
    buf.writeln('${indent}await __mutEntityCache.setPendingSync($idExpr, false);');
  }
  return buf.toString();
}

String buildMutationCommandMethod({
  required String endpointClassName,
  required String clientField,
  required MyMethodMeta method,
  Map<String, EntityCacheTemplate> entityCacheTemplates = const {},
  Map<String, String> methodToClientField = const {},
}) {
  final meta = method.mutationCommand!;
  final template = entityCacheTemplates[meta.affects];
  final hook = 'invalidateAfter${ReCase(method.name).pascalCase}';
  final refClass = 'Ref$endpointClassName';
  final retryEnabled = meta.retry != 'RetryPolicy.none';
  final queueId = _mutationQueueIdExpression(endpointClassName, method, meta);
  final timeoutSuffix =
      method.timeout != null ? '.timeout(const ${method.timeout})' : '';

  final readCall =
      'read(clientProvider).$clientField.${method.name}(${_mutationCallArgs(method)})$timeoutSuffix';

  final needsCache = _needsMutationEntityCacheOpen(
    meta: meta,
    method: method,
    template: template,
    methodToClientField: methodToClientField,
  );
  final idExpr = _mutationIdExpression(meta, method);
  final useOptimistic = meta.optimistic == 'OptimisticPolicy.patchLocalCache' &&
      idExpr != null &&
      template != null &&
      needsCache;

  final buffer = StringBuffer();
  buffer.writeln(
    '  static const DialogPolicy dialogPolicyAfter${ReCase(method.name).pascalCase} = ${meta.closeDialog};',
  );
  buffer.writeln();
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

  if (useOptimistic) {
    buffer.writeln('    ${template!.elementType}? __mutOptimisticPrev;');
  }

  if (needsCache && template != null) {
    final t = template;
    buffer.writeln(
      '    final __mutStorage = await read(${_mutationEntityStorageProviderName(t)}.future);',
    );
    buffer.writeln(
      '    final __mutEntityCache = GeneratedEntityCache<${t.elementType}>(',
    );
    buffer.writeln('      storage: __mutStorage,');
    buffer.writeln("      entityType: r'${t.entityTypeKey}',");
    buffer.writeln('      cacheVersion: ${t.cacheVersion},');
    buffer.writeln('      idOf: (e) => e.${t.idField},');
    buffer.writeln('      toJson: (e) => Map<String, Object?>.from(e.toJson()),');
    buffer.writeln('      fromJson: ${t.elementType}.fromJson,');
    buffer.writeln('      maxItems: ${t.maxItems},');
    buffer.writeln('    );');
    if (useOptimistic) {
      buffer.writeln(
        '    __mutOptimisticPrev = await __mutEntityCache.getById($idExpr);',
      );
      buffer.writeln('    if (__mutOptimisticPrev != null) {');
      buffer.writeln(
        '      await __mutEntityCache.putOne(__mutOptimisticPrev!, pendingSync: true);',
      );
      buffer.writeln('    }');
    }
  }

  buffer.writeln('    try {');

  final postSuccess = (needsCache && template != null)
      ? _mutationPostSuccessEntityCacheLines(
          meta: meta,
          method: method,
          template: template,
          methodToClientField: methodToClientField,
          indent: '      ',
        )
      : '';

  if (method.unwrappedReturnType == 'void') {
    buffer.writeln('      await $readCall;');
    if (postSuccess.isNotEmpty) buffer.write(postSuccess);
    buffer.writeln('      $refClass.$hook(read);');
  } else {
    buffer.writeln('      final result = await $readCall;');
    if (postSuccess.isNotEmpty) buffer.write(postSuccess);
    buffer.writeln('      $refClass.$hook(read);');
    buffer.writeln('      return result;');
  }

  buffer.writeln(r'    } catch (e, st) {');
  buffer.writeln('      final __enqueue = mutationFailureShouldEnqueue(');
  buffer.writeln('            error: e,');
  buffer.writeln('            idempotent: ${meta.idempotent},');
  buffer.writeln('            retryEnabled: $retryEnabled,');
  buffer.writeln('          );');
  if (useOptimistic) {
    buffer.writeln(
      r'      if (!__enqueue && __mutOptimisticPrev != null) {',
    );
    buffer.writeln(
      '        await __mutEntityCache.putOne(__mutOptimisticPrev!, pendingSync: false);',
    );
    buffer.writeln('      }');
  }
  buffer.writeln('      if (__enqueue) {');
  buffer.writeln(
      '        final retrySnapshot = read(mutationRetryQueueProvider).schedule(');
  buffer.writeln('          id: $queueId,');
  buffer.writeln('          idempotent: ${meta.idempotent},');
  buffer.writeln("          label: r'${method.name}',");
  if (meta.idempotent) {
    buffer.writeln('          persistPayload: MutationRetryPersistedPayload(');
    buffer.writeln(
      "            opKey: r'$endpointClassName.${method.name}',",
    );
    buffer.writeln('            args: {${_mutationPersistArgsMap(method)}},');
    buffer.writeln('          ),');
  }
  buffer.writeln('          run: () async {');
  _writeMutationCommandValidations(buffer, method, indent: '            ');
  if (method.unwrappedReturnType == 'void') {
    buffer.writeln('            await $readCall;');
  } else {
    buffer.writeln('            final result = await $readCall;');
  }
  if (postSuccess.isNotEmpty) {
    final retryPost = postSuccess.replaceAll('      ', '            ');
    buffer.write(retryPost);
  }
  buffer.writeln('            $refClass.$hook(read);');
  buffer.writeln('          },');
  buffer.writeln('        );');
  buffer.writeln(
      '        read(refreshWarningProvider.notifier).recordQueuedMutation(');
  buffer.writeln('          mutationId: retrySnapshot.id,');
  buffer.writeln(
      '          queuedMutationCount: read(mutationRetryQueueProvider).length,');
  buffer.writeln('          error: e,');
  buffer.writeln('          nextRetryAt: retrySnapshot.nextRetryAt,');
  buffer.writeln('        );');
  buffer.writeln('      }');
  buffer.writeln('      rethrow;');
  buffer.writeln('    }');
  buffer.writeln('  }');
  return buffer.toString();
}

String _mutationPersistArgsMap(MyMethodMeta method) {
  final parts = <String>[
    for (final p in method.positionalParams)
      "r'${p.name}': ${p.name}",
    for (final p in method.namedParams)
      "r'${p.name}': ${p.name}",
  ];
  return parts.join(', ');
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
