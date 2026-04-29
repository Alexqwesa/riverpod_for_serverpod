import 'package:code_builder/code_builder.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';

/// Returns a code suffix that appends .timeout(const Duration(...)) when set.
String _timeoutSuffix(MyMethodMeta m) =>
    m.timeout != null ? '.timeout(const ${m.timeout})' : '';

Field buildProviderField(
  MyMethodMeta m,
  String unWrapperReturnType,
  String innerCode,
  String clientField,
) {
  if (m.positionalParams.length == 1 && m.namedParams.isEmpty) {
    return buildSinglePositionalField(m, unWrapperReturnType, innerCode, clientField);
  }
  if (m.positionalParams.isEmpty && m.namedParams.length == 1) {
    return buildSingleNamedField(m, unWrapperReturnType, innerCode, clientField);
  }
  if (m.hasPositionalParams || m.hasNamedParams) {
    return buildMixedOrMultiParamField(m, unWrapperReturnType, innerCode, clientField);
  }
  return buildZeroParamField(m, unWrapperReturnType, innerCode, clientField);
}

Field buildZeroParamField(MyMethodMeta m, String returnType, String innerCode, String clientField) {
  return Field((mb) {
    mb
      ..static = true
      ..modifier = FieldModifier.final$
      ..name = m.name
      ..assignment = Code('''
FutureProvider.autoDispose<$returnType>(
  (ref) {
    $innerCode
   return ref.watch(clientProvider).$clientField.${m.name}()${_timeoutSuffix(m)};
   }
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
    return ref.watch(clientProvider).$clientField.${m.name}(${p.name})${_timeoutSuffix(m)} as FutureOr<$returnType>;
    },
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
    return ref.watch(clientProvider).$clientField.${m.name}(${p.name}: ${p.name})${_timeoutSuffix(m)} as FutureOr<$returnType>;
    }
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

  return Field((mb) {
    mb
      ..static = true
      ..modifier = FieldModifier.final$
      ..name = m.name
      ..assignment = Code('''
FutureProvider.autoDispose.family<$returnType, $recordType>(
  (ref, args)  {
    $innerCode
    $destructuredVars
    return ref.watch(clientProvider).$clientField.${m.name}($methodCall)${_timeoutSuffix(m)} as FutureOr<$returnType>;
  },
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
      destructuringPattern = '(${m.positionalParams.map((p) => p.name).join(', ')})';
      destructuredVars = 'final $destructuringPattern = args;';
    }
  } else if (m.hasNamedParams) {
    if (m.namedParams.length == 1) {
      final p = m.namedParams.first;
      recordType = '({${p.type} ${p.name}})';
      destructuringPattern = '(${p.name}: ${p.name})';
      destructuredVars = 'final $destructuringPattern = args;';
    } else {
      recordType = '({${m.namedParams.map((p) => '${p.type} ${p.name}').join(', ')}})';
      destructuringPattern = '(${m.namedParams.map((p) => '${p.name}: ${p.name}').join(', ')})';
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
