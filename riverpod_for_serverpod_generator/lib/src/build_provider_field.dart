import 'package:code_builder/code_builder.dart';
import 'package:riverpod_for_serverpod_generator/src/build_cached_query_notifier.dart';
import 'package:riverpod_for_serverpod_generator/src/cached_query_codegen.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';

/// Returns a code suffix that appends .timeout(const Duration(...)) when set.
String _timeoutSuffix(MyMethodMeta m) =>
    m.timeout != null ? '.timeout(const ${m.timeout})' : '';

String _clientCall(MyMethodMeta m, String clientField, String args) =>
    'ref.watch(clientProvider).$clientField.${m.name}($args)${_timeoutSuffix(m)}';

String _successfulResultBody(
  MyMethodMeta m,
  String returnType,
  String clientField,
  String args,
) {
  final call = _clientCall(m, clientField, args);
  final cacheFor = 'ref.cacheFor(const ${m.cacheTtl});';
  final cachedShape = m.cachedQuery == null
      ? null
      : parseCachedQueryReturnType(returnType);

  if (m.cachedQuery != null && cachedShape != null) {
    final clientAwait = 'final result = await $call;';
    final core = buildCachedQueryBlock(
      m: m,
      shape: cachedShape,
      clientCallAwaitResult: clientAwait,
      cacheForLine: cacheFor,
    );
    return '''
$core
    $cacheFor
    return result;
''';
  }

  if (returnType == 'void') {
    return '''
await $call;
    $cacheFor
''';
  }

  return '''
final result = await $call;
    $cacheFor
    return result;
''';
}

String _withCachedQueryRefreshFailureReporting(
  MyMethodMeta m,
  String successBody,
) {
  if (m.cachedQuery == null) return successBody;
  final inner =
      successBody.trimRight().split('\n').map((line) => '    $line').join('\n');
  return '''
try {
$inner
  } catch (e, st) {
    ref.read(refreshWarningProvider.notifier).recordFailure(
          sourceKey: r'${m.innerProviderName}.${m.name}',
          error: e,
        );
    rethrow;
  }
''';
}

Field buildProviderField(
  MyMethodMeta m,
  String unWrapperReturnType,
  String innerCode,
  String clientField,
) {
  if (m.positionalParams.length == 1 && m.namedParams.isEmpty) {
    return buildSinglePositionalField(
      m,
      unWrapperReturnType,
      innerCode,
      clientField,
    );
  }
  if (m.positionalParams.isEmpty && m.namedParams.length == 1) {
    return buildSingleNamedField(
      m,
      unWrapperReturnType,
      innerCode,
      clientField,
    );
  }
  if (m.hasPositionalParams || m.hasNamedParams) {
    return buildMixedOrMultiParamField(
      m,
      unWrapperReturnType,
      innerCode,
      clientField,
    );
  }
  return buildZeroParamField(m, unWrapperReturnType, innerCode, clientField);
}

Field buildZeroParamField(
  MyMethodMeta m,
  String returnType,
  String innerCode,
  String clientField,
) {
  if (useCachedQueryAsyncNotifierSwr(m, returnType)) {
    final cn = cachedReadNotifierClassName(m);
    return Field((mb) {
      mb
        ..static = true
        ..modifier = FieldModifier.final$
        ..name = m.name
        ..assignment = Code('''
AsyncNotifierProvider.autoDispose<$cn, $returnType>(
  $cn.new,
  retry: _noProviderRetry,
)
''');
    });
  }
  return Field((mb) {
    mb
      ..static = true
      ..modifier = FieldModifier.final$
      ..name = m.name
      ..assignment = Code('''
FutureProvider.autoDispose<$returnType>(
  (ref) async {
    $innerCode
    ${_withCachedQueryRefreshFailureReporting(m, _successfulResultBody(m, returnType, clientField, ''))}
   },
   retry: _noProviderRetry,
)
''');
  });
}

Field buildSinglePositionalField(
  MyMethodMeta m,
  String returnType,
  String innerCode,
  String clientField,
) {
  final p = m.positionalParams.first;
  if (useCachedQueryAsyncNotifierSwr(m, returnType)) {
    final cn = cachedReadNotifierClassName(m);
    return Field((mb) {
      mb
        ..static = true
        ..modifier = FieldModifier.final$
        ..name = m.name
        ..assignment = Code('''
AsyncNotifierProvider.family
    .autoDispose<$cn, $returnType, ${p.type}>(
  $cn.new,
  retry: _noProviderRetry,
)
''');
    });
  }
  return Field((mb) {
    mb
      ..static = true
      ..modifier = FieldModifier.final$
      ..name = m.name
      ..assignment = Code('''
FutureProvider.autoDispose
    .family<$returnType, ${p.type}>(
  (ref, ${p.name}) async {
    $innerCode
    ${_withCachedQueryRefreshFailureReporting(m, _successfulResultBody(m, returnType, clientField, p.name))}
    },
    retry: _noProviderRetry,
)
''');
  });
}

Field buildSingleNamedField(
  MyMethodMeta m,
  String returnType,
  String innerCode,
  String clientField,
) {
  final p = m.namedParams.first;
  if (useCachedQueryAsyncNotifierSwr(m, returnType)) {
    final cn = cachedReadNotifierClassName(m);
    return Field((mb) {
      mb
        ..static = true
        ..modifier = FieldModifier.final$
        ..name = m.name
        ..assignment = Code('''
AsyncNotifierProvider.family
    .autoDispose<$cn, $returnType, ${p.type}>(
  $cn.new,
  retry: _noProviderRetry,
)
''');
    });
  }
  return Field((mb) {
    mb
      ..static = true
      ..modifier = FieldModifier.final$
      ..name = m.name
      ..assignment = Code('''
FutureProvider.autoDispose
    .family<$returnType, ${p.type}>(
  (ref, ${p.name}) async {
    $innerCode
    ${_withCachedQueryRefreshFailureReporting(m, _successfulResultBody(m, returnType, clientField, '${p.name}: ${p.name}'))}
    },
    retry: _noProviderRetry,
)
''');
  });
}

Field buildMixedOrMultiParamField(
  MyMethodMeta m,
  String returnType,
  String innerCode,
  String clientField,
) {
  final paramInfo = buildRecordTypeAndDestructure(m);
  final recordType = paramInfo.recordType;
  final destructuredVars = paramInfo.destructuredVars;
  final methodCall = paramInfo.methodCall;

  if (useCachedQueryAsyncNotifierSwr(m, returnType)) {
    final cn = cachedReadNotifierClassName(m);
    final argT = _swrFamilyArgType(m);
    return Field((mb) {
      mb
        ..static = true
        ..modifier = FieldModifier.final$
        ..name = m.name
        ..assignment = Code('''
AsyncNotifierProvider.family
    .autoDispose<$cn, $returnType, $argT>(
  $cn.new,
  retry: _noProviderRetry,
)
''');
    });
  }

  return Field((mb) {
    mb
      ..static = true
      ..modifier = FieldModifier.final$
      ..name = m.name
      ..assignment = Code('''
FutureProvider.autoDispose.family<$returnType, $recordType>(
  (ref, args) async {
    $innerCode
    $destructuredVars
    ${_withCachedQueryRefreshFailureReporting(m, _successfulResultBody(m, returnType, clientField, methodCall))}
  },
  retry: _noProviderRetry,
)
''');
  });
}

ParamInfo buildRecordTypeAndDestructure(MyMethodMeta m) {
  String recordType;
  String destructuringPattern;
  String destructuredVars;

  if (m.hasPositionalParams && m.hasNamedParams) {
    recordType =
        '(${m.positionalParams.map((p) => p.type).join(', ')}, {${m.namedParams.map((p) => '${p.type} ${p.name}').join(', ')}})';
    destructuringPattern =
        '(${m.positionalParams.map((p) => p.name).join(', ')}, ${m.namedParams.map((p) => '${p.name}: ${p.name}').join(', ')})';
    destructuredVars = 'final $destructuringPattern = args;';
  } else if (m.hasPositionalParams) {
    if (m.positionalParams.length == 1) {
      final p = m.positionalParams.first;
      recordType = p.type;
      destructuringPattern = p.name;
      destructuredVars = 'final $destructuringPattern = args;';
    } else {
      recordType = '(${m.positionalParams.map((p) => p.type).join(', ')})';
      destructuringPattern =
          '(${m.positionalParams.map((p) => p.name).join(', ')})';
      destructuredVars = 'final $destructuringPattern = args;';
    }
  } else if (m.hasNamedParams) {
    if (m.namedParams.length == 1) {
      final p = m.namedParams.first;
      recordType = '({${p.type} ${p.name}})';
      destructuringPattern = '(${p.name}: ${p.name})';
      destructuredVars = 'final $destructuringPattern = args;';
    } else {
      recordType =
          '({${m.namedParams.map((p) => '${p.type} ${p.name}').join(', ')}})';
      destructuringPattern =
          '(${m.namedParams.map((p) => '${p.name}: ${p.name}').join(', ')})';
      destructuredVars = 'final $destructuringPattern = args;';
    }
  } else {
    recordType = '()';
    destructuredVars = '';
  }

  final methodCallParams = <String>[];
  if (m.hasPositionalParams) {
    methodCallParams.addAll(m.positionalParams.map((p) => p.name));
  }
  if (m.hasNamedParams) {
    methodCallParams.addAll(m.namedParams.map((p) => '${p.name}: ${p.name}'));
  }
  final methodCall = methodCallParams.join(', ');

  return ParamInfo(recordType, destructuredVars, methodCall);
}

/// SWR = Stale While Revalidate.
SwrNotifierHostParams swrNotifierHostParams(MyMethodMeta m) {
  if (!m.hasPositionalParams && !m.hasNamedParams) {
    return const SwrNotifierHostParams(
      instanceFields: '',
      constructorParams: '',
      buildParamPrelude: '',
      rpcArgs: '',
    );
  }
  if (m.positionalParams.length == 1 && m.namedParams.isEmpty) {
    final p = m.positionalParams.first;
    return SwrNotifierHostParams(
      instanceFields: 'final ${p.type} ${p.name};',
      constructorParams: 'this.${p.name}',
      buildParamPrelude: '',
      rpcArgs: p.name,
    );
  }
  if (m.namedParams.length == 1 && m.positionalParams.isEmpty) {
    final p = m.namedParams.first;
    return SwrNotifierHostParams(
      instanceFields: 'final ${p.type} ${p.name};',
      constructorParams: 'this.${p.name}',
      buildParamPrelude: '',
      rpcArgs: '${p.name}: ${p.name}',
    );
  }
  final pi = buildRecordTypeAndDestructure(m);
  return SwrNotifierHostParams(
    instanceFields: 'final ${pi.recordType} _args;',
    constructorParams: 'this._args',
    buildParamPrelude:
        '${pi.destructuredVars.replaceAll('= args;', '= _args;')}\n',
    rpcArgs: pi.methodCall,
  );
}

String _swrFamilyArgType(MyMethodMeta m) {
  if (!m.hasPositionalParams && !m.hasNamedParams) {
    throw StateError('SWR family arg type requires parameters');
  }
  if (m.positionalParams.length == 1 && m.namedParams.isEmpty) {
    return m.positionalParams.first.type;
  }
  if (m.namedParams.length == 1 && m.positionalParams.isEmpty) {
    return m.namedParams.first.type;
  }
  return buildRecordTypeAndDestructure(m).recordType;
}
