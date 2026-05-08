import 'package:code_builder/code_builder.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';

class ProviderVariantSpec {
  final String name;
  final int index;
  final String argType;
  final String argDestructureCode;
  final String canonicalArgsExpression;
  final bool shouldUseFamily;

  const ProviderVariantSpec({
    required this.name,
    required this.index,
    required this.argType,
    required this.argDestructureCode,
    required this.canonicalArgsExpression,
    required this.shouldUseFamily,
  });
}

Iterable<ProviderVariantSpec> buildProviderVariantSpecs(MyMethodMeta m) sync* {
  final pos = m.positionalParams;
  final named = m.namedParams;

  final defaultables = [
    for (final p in named)
      if (p.isNullable || p.hasDefault) p,
  ];
  final requiredNamed = named.where((p) => !defaultables.contains(p)).toList();

  if (pos.isNotEmpty || named.isNotEmpty) {
    yield _buildVariantSpec(
      m: m,
      baseName: m.name,
      variantIndex: 0,
      positionalParams: pos,
      requiredNamedParams: requiredNamed,
      defaultableParams: defaultables,
    );
  }

  if (defaultables.isNotEmpty) {
    for (int i = 1; i <= defaultables.length; i++) {
      yield _buildVariantSpec(
        m: m,
        baseName: m.name,
        variantIndex: i,
        positionalParams: pos,
        requiredNamedParams: requiredNamed,
        defaultableParams: defaultables,
        takeCount: i,
      );
    }
  }
}

ProviderVariantSpec _buildVariantSpec({
  required MyMethodMeta m,
  required String baseName,
  required int variantIndex,
  required List<MyParamMeta> positionalParams,
  required List<MyParamMeta> requiredNamedParams,
  required List<MyParamMeta> defaultableParams,
  int? takeCount,
}) {
  final vName = '$baseName$variantIndex';

  final usedDefaultables = takeCount != null
      ? defaultableParams.take(takeCount).toList()
      : <MyParamMeta>[];

  final shouldUseFamily = [
    ...positionalParams,
    ...requiredNamedParams,
    ...usedDefaultables,
  ].isNotEmpty;

  final (recordType, destructuredVars, callArgs) = _buildVariantParameters(
    positionalParams: positionalParams,
    requiredNamedParams: requiredNamedParams,
    defaultableParams: defaultableParams,
    takeCount: takeCount,
    shouldUseFamily: shouldUseFamily,
  );

  return ProviderVariantSpec(
    name: vName,
    index: variantIndex,
    argType: recordType,
    argDestructureCode: destructuredVars,
    canonicalArgsExpression: callArgs,
    shouldUseFamily: shouldUseFamily,
  );
}

Iterable<Field> buildProviderVariants(
  MyMethodMeta m,
  String returnType,
  String innerCode,
  String clientField,
  String refClassName,
) sync* {
  for (final variant in buildProviderVariantSpecs(m)) {
    yield _buildVariantField(
      m: m,
      returnType: returnType,
      innerCode: innerCode,
      refClassName: refClassName,
      variant: variant,
    );
  }
}

Field _buildVariantField({
  required MyMethodMeta m,
  required String returnType,
  required String innerCode,
  required String refClassName,
  required ProviderVariantSpec variant,
}) {
  final providerCode = variant.shouldUseFamily
      ? '''
FutureProvider.autoDispose.family<$returnType, ${variant.argType}>(
  (ref, arg) {
    ${variant.argDestructureCode}
    return ref.watch($refClassName.${m.name}(${variant.canonicalArgsExpression}).future);
  },
  retry: _noProviderRetry,
)
'''
      : '''
FutureProvider.autoDispose<$returnType>(
  (ref) {
    return ref.watch($refClassName.${m.name}(${variant.canonicalArgsExpression}).future);
  },
  retry: _noProviderRetry,
)
''';

  return Field((mb) {
    mb
      ..static = true
      ..modifier = FieldModifier.final$
      ..name = variant.name
      ..assignment = Code(providerCode);
  });
}

(String recordType, String destructuredVars, String callArgs)
    _buildVariantParameters({
  required List<MyParamMeta> positionalParams,
  required List<MyParamMeta> requiredNamedParams,
  required List<MyParamMeta> defaultableParams,
  required int? takeCount,
  required bool shouldUseFamily,
}) {
  // NO-FAMILY CASE:
  // Provider has no external args, but the endpoint method may still have
  // parameters (only defaultables). We still must build the call args.
  if (!shouldUseFamily) {
    final callArgs = buildCallArgs(
      positionalParams: positionalParams,
      requiredNamedParams: requiredNamedParams,
      defaultableParams: defaultableParams,
      takeCount: null, // no exposed defaultables → all use defaults
    );
    return ('void', '', callArgs);
  }

  final usedDefaultables = takeCount != null
      ? defaultableParams.take(takeCount).toList()
      : <MyParamMeta>[];
  final allUsedParams = [
    ...positionalParams,
    ...requiredNamedParams,
    ...usedDefaultables
  ];

  // Single parameter case – no record wrapping for the arg
  if (allUsedParams.length == 1) {
    final singleParam = allUsedParams.first;

    final callArgs = buildCallArgs(
      positionalParams: positionalParams,
      requiredNamedParams: requiredNamedParams,
      defaultableParams: defaultableParams,
      takeCount: takeCount,
    );

    return (singleParam.type, 'final ${singleParam.name} = arg;', callArgs);
  }

  // Multiple parameters – use a record for arg
  final recordType = _buildRecordType(
    positionalParams: positionalParams,
    requiredNamedParams: requiredNamedParams,
    defaultableParams: defaultableParams,
    takeCount: takeCount,
  );

  final destructuredVars = _buildDestructuringCode(
    positionalParams: positionalParams,
    requiredNamedParams: requiredNamedParams,
    defaultableParams: defaultableParams,
    takeCount: takeCount,
  );

  final callArgs = buildCallArgs(
    positionalParams: positionalParams,
    requiredNamedParams: requiredNamedParams,
    defaultableParams: defaultableParams,
    takeCount: takeCount,
  );

  return (recordType, destructuredVars, callArgs);
}

String _buildRecordType({
  required List<MyParamMeta> positionalParams,
  required List<MyParamMeta> requiredNamedParams,
  required List<MyParamMeta> defaultableParams,
  required int? takeCount,
}) {
  final usedDefaultables = takeCount != null
      ? defaultableParams.take(takeCount).toList()
      : <MyParamMeta>[];
  final allUsedParams = [
    ...positionalParams,
    ...requiredNamedParams,
    ...usedDefaultables
  ];

  // Single parameter case handled in _buildVariantParameters
  if (allUsedParams.length == 1) {
    return allUsedParams.first.type;
  }

  final recordPosTypes = positionalParams.map((p) => p.type).join(', ');
  final recordNamedFields = <String>[
    for (final p in requiredNamedParams) '${p.type} ${p.name}',
    for (final p in usedDefaultables) '${p.type} ${p.name}',
  ];

  return positionalParams.isEmpty
      ? '({${recordNamedFields.join(', ')}})'
      : '($recordPosTypes${recordNamedFields.isEmpty ? '' : ', {${recordNamedFields.join(', ')}}'})';
}

String _buildDestructuringCode({
  required List<MyParamMeta> positionalParams,
  required List<MyParamMeta> requiredNamedParams,
  required List<MyParamMeta> defaultableParams,
  required int? takeCount,
}) {
  final usedDefaultables = takeCount != null
      ? defaultableParams.take(takeCount).toList()
      : <MyParamMeta>[];
  final allUsedParams = [
    ...positionalParams,
    ...requiredNamedParams,
    ...usedDefaultables
  ];

  // Single parameter case handled in _buildVariantParameters
  if (allUsedParams.length == 1) {
    return '';
  }

  final posNames = positionalParams.map((p) => p.name).join(', ');

  final namedDestruct = [
    for (final p in requiredNamedParams) '${p.name}: ${p.name}',
    for (final p in usedDefaultables) '${p.name}: ${p.name}',
  ].join(', ');

  final destructuringPattern = positionalParams.isEmpty
      ? '($namedDestruct)'
      : '($posNames${namedDestruct.isEmpty ? '' : ', $namedDestruct'})';

  return 'final $destructuringPattern = arg;';
}

String buildCallArgs({
  required List<MyParamMeta> positionalParams,
  required List<MyParamMeta> requiredNamedParams,
  required List<MyParamMeta> defaultableParams,
  required int? takeCount,
}) {
  // Which defaultables are explicitly used as *variables* (chosen via takeCount)
  final usedDefaultables = takeCount != null
      ? defaultableParams.take(takeCount).toList()
      : <MyParamMeta>[];

  // Positional names
  final posNames = <String>[for (final p in positionalParams) p.name];

  // Named pairs with dedup
  final usedNames = <String>{...posNames};

  String valueFor(MyParamMeta p) {
    // If no explicit default and type is nullable → null
    if (p.defaultCodeOrNull == null) return 'null';
    return p.defaultCodeOrNull ?? p.name;
  }

  final namedPairs = <(String, String)>[
    // required named → always variable
    for (final p in requiredNamedParams)
      if (usedNames.add(p.name)) (p.name, p.name),

    // explicitly exposed defaultables → variable
    for (final p in usedDefaultables)
      if (usedNames.add(p.name)) (p.name, p.name),

    // remaining defaultables → default/null
    for (final p in defaultableParams)
      if (usedNames.add(p.name)) (p.name, valueFor(p)),
  ];

  final totalArgs = posNames.length + namedPairs.length;

  // 0 args → nothing
  if (totalArgs == 0) {
    return '';
  }

  // 1 arg → pass single variable/value directly
  if (totalArgs == 1) {
    if (posNames.isNotEmpty) return posNames.first; // 1 positional
    return namedPairs.first.$2; // 1 named
  }

  // >1 args → record literal
  return buildRecordValueArgs(positional: posNames, namedPairs: namedPairs);
}

String buildRecordValueArgs({
  required List<String> positional,
  required List<(String name, String value)> namedPairs,
}) {
  final named = namedPairs.map((e) => '${e.$1}: ${e.$2}').toList();

  final pieces = <String>[];
  pieces.addAll(positional);
  pieces.addAll(named);

  return '(${pieces.join(', ')})';
}
