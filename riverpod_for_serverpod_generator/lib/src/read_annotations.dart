import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';

/// Safely reconstruct a Duration from a ConstantReader that points to a const Duration.
// Duration _readDuration(ConstantReader r) {
//   final obj = r.objectValue;
//
//   // The core trick: read the const Duration's microseconds at build-time
//   final micros = obj.getField('inMicroseconds')?.toIntValue();
//
//   if (micros == null) {
//     throw InvalidGenerationSourceError(
//       'cacheTtl requires a const Duration literal, e.g. @cacheTtl(Duration(minutes: 3))',
//     );
//   }
//   return Duration(microseconds: micros);
// }

Duration readCacheTtlOrDefault(Element element,
    {Duration orDefault = const Duration(minutes: 3)}) {
  for (final meta in element.metadata.annotations) {
    final value = meta.computeConstantValue();
    if (value == null) continue;

    final typeName = value.type?.getDisplayString();
    if (typeName == 'CacheTtl' /* or 'CacheTtl' if you used UpperCamel */) {
      final micros = value.getField('microseconds')?.toIntValue();
      if (micros != null) return Duration(microseconds: micros);
    }
  }
  return orDefault;
}

/// Returns the literal argument as written in source, e.g. "Duration(minutes: 5)".
/// If not found, returns null.
String? extractCacheTtlLiteral(AnnotatedNode node) {
  return extractSingleArgumentAnnotationLiteral(node, 'CacheTtl');
}

String? extractTimeoutLiteral(AnnotatedNode node) {
  return extractSingleArgumentAnnotationLiteral(node, 'Timeout');
}

CachedQueryMeta? extractCachedQueryMeta(AnnotatedNode node) {
  final ann = _annotation(node, 'CachedQuery');
  if (ann == null) return null;

  final args = _argumentMap(ann);
  final entity = _sourceArg(args, 'entity') ?? _sourceArg(args, '#0');
  if (entity == null || entity.isEmpty) return null;

  return CachedQueryMeta(
    entity: entity,
    idField: _stringArg(args, 'idField') ?? 'id',
    maxItems: _intArg(args, 'maxItems') ?? 1000,
    ttl: _sourceArg(args, 'ttl') ?? 'Duration(minutes: 3)',
    secure: _boolArg(args, 'secure') ?? false,
    byIdMethod: _stringArg(args, 'byIdMethod'),
    mergePolicy:
        _sourceArg(args, 'mergePolicy') ?? 'CacheMergePolicy.replaceEntity',
    cacheVersion: _intArg(args, 'cacheVersion') ?? 1,
    backgroundRefresh: _boolArg(args, 'backgroundRefresh') ?? true,
  );
}

MutationCommandMeta? extractMutationCommandMeta(AnnotatedNode node) {
  final ann = _annotation(node, 'MutationCommand');
  if (ann == null) return null;

  final args = _argumentMap(ann);
  final affects = _sourceArg(args, 'affects') ?? _sourceArg(args, '#0');
  if (affects == null || affects.isEmpty) return null;

  return MutationCommandMeta(
    affects: affects,
    idArg: _stringArg(args, 'idArg'),
    idField: _stringArg(args, 'idField') ?? 'id',
    byIdMethod: _stringArg(args, 'byIdMethod'),
    invalidate: _invalidateListArg(args, 'invalidate'),
    optimistic: _sourceArg(args, 'optimistic') ?? 'OptimisticPolicy.none',
    retry: _sourceArg(args, 'retry') ?? 'RetryPolicy.connectionOnly',
    refetch: _sourceArg(args, 'refetch') ?? 'RefetchPolicy.byId',
    idempotent: _boolArg(args, 'idempotent') ?? false,
    idempotencyKeyArg: _stringArg(args, 'idempotencyKeyArg'),
    closeDialog:
        _sourceArg(args, 'closeDialog') ?? 'DialogPolicy.onSuccessOnly',
  );
}

List<ValidateStringMeta> extractValidateStringMeta(AnnotatedNode node) {
  return [
    for (final ann in _annotations(node, 'ValidateString'))
      if (_validateStringMeta(ann) case final meta?) meta,
  ];
}

List<ValidateNumberMeta> extractValidateNumberMeta(AnnotatedNode node) {
  return [
    for (final ann in _annotations(node, 'ValidateNumber'))
      if (_validateNumberMeta(ann) case final meta?) meta,
  ];
}

List<ValidateListMeta> extractValidateListMeta(AnnotatedNode node) {
  return [
    for (final ann in _annotations(node, 'ValidateList'))
      if (_validateListMeta(ann) case final meta?) meta,
  ];
}

List<String> extractInvalidateTargets(AnnotatedNode node) {
  for (final ann in node.metadata) {
    if (_annotationName(ann) != 'RefInvalidate') continue;
    final args = ann.arguments?.arguments;
    if (args == null || args.isEmpty) return const [];

    final first = args.first;
    final expr = first is NamedExpression ? first.expression : first;
    if (expr is! ListLiteral) return const [];

    return expr.elements
        .whereType<StringLiteral>()
        .map((element) => element.stringValue?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

bool extractInvalidateIncludesSelf(AnnotatedNode node) {
  for (final ann in node.metadata) {
    if (_annotationName(ann) != 'RefInvalidate') continue;
    final args = ann.arguments?.arguments;
    if (args == null || args.isEmpty) return true;
    for (final arg in args.whereType<NamedExpression>()) {
      if (arg.name.label.name != 'includeSelf') continue;
      final value = arg.expression;
      if (value is BooleanLiteral) return value.value;
    }
  }
  return true;
}

bool hasDoNotGenerateAnnotation(AnnotatedNode node) {
  return node.metadata.any((ann) {
    final name = _annotationName(ann);
    return name == 'DoNotGenerate' || name == 'doNotGenerate';
  });
}

ValidateStringMeta? _validateStringMeta(Annotation ann) {
  final args = _argumentMap(ann);
  final arg = _stringArg(args, 'arg');
  if (arg == null || arg.isEmpty) return null;
  return ValidateStringMeta(
    arg: arg,
    notEmpty: _boolArg(args, 'notEmpty') ?? false,
    minLength: _intArg(args, 'minLength'),
    maxLength: _intArg(args, 'maxLength'),
    pattern: _stringArg(args, 'pattern'),
  );
}

ValidateNumberMeta? _validateNumberMeta(Annotation ann) {
  final args = _argumentMap(ann);
  final arg = _stringArg(args, 'arg');
  if (arg == null || arg.isEmpty) return null;
  return ValidateNumberMeta(
    arg: arg,
    min: _numArg(args, 'min'),
    max: _numArg(args, 'max'),
  );
}

ValidateListMeta? _validateListMeta(Annotation ann) {
  final args = _argumentMap(ann);
  final arg = _stringArg(args, 'arg');
  if (arg == null || arg.isEmpty) return null;
  return ValidateListMeta(
    arg: arg,
    notEmpty: _boolArg(args, 'notEmpty') ?? false,
    minLength: _intArg(args, 'minLength'),
    maxLength: _intArg(args, 'maxLength'),
  );
}

List<InvalidateMeta> _invalidateListArg(
  Map<String, Expression> args,
  String name,
) {
  final expr = args[name];
  if (expr is! ListLiteral) return const [];
  return [
    for (final element in expr.elements.whereType<Expression>())
      if (_invalidateMeta(element) case final meta?) meta,
  ];
}

InvalidateMeta? _invalidateMeta(Expression expr) {
  if (expr is MethodInvocation &&
      expr.target?.toSource() == 'Invalidate' &&
      expr.argumentList.arguments.isNotEmpty) {
    final provider = _stringExpression(expr.argumentList.arguments.first);
    if (provider == null || provider.isEmpty) return null;
    switch (expr.methodName.name) {
      case 'all':
        return InvalidateMeta.all(provider);
      case 'family':
        final args = _expressionArgumentMap(expr.argumentList.arguments);
        final argFrom = _stringArg(args, 'argFrom');
        if (argFrom == null || argFrom.isEmpty) return null;
        return InvalidateMeta.family(provider, argFrom: argFrom);
    }
  }
  return null;
}

Annotation? _annotation(AnnotatedNode node, String name) {
  for (final ann in node.metadata) {
    if (_annotationName(ann) == name) return ann;
  }
  return null;
}

List<Annotation> _annotations(AnnotatedNode node, String name) {
  return [
    for (final ann in node.metadata)
      if (_annotationName(ann) == name) ann,
  ];
}

Map<String, Expression> _argumentMap(Annotation ann) {
  final args = ann.arguments?.arguments;
  if (args == null) return const {};
  return _expressionArgumentMap(args);
}

Map<String, Expression> _expressionArgumentMap(NodeList<Expression> args) {
  final result = <String, Expression>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg is NamedExpression) {
      result[arg.name.label.name] = arg.expression;
    } else {
      result['#$i'] = arg;
    }
  }
  return result;
}

String? _sourceArg(Map<String, Expression> args, String name) {
  final expr = args[name];
  if (expr == null) return null;
  return _cleanSource(expr.toSource());
}

String? _stringArg(Map<String, Expression> args, String name) {
  return _stringExpression(args[name]);
}

String? _stringExpression(Expression? expr) {
  if (expr is StringLiteral) return expr.stringValue;
  return null;
}

int? _intArg(Map<String, Expression> args, String name) {
  final expr = args[name];
  if (expr is IntegerLiteral) return expr.value;
  return null;
}

num? _numArg(Map<String, Expression> args, String name) {
  final expr = args[name];
  if (expr is IntegerLiteral) return expr.value;
  if (expr is DoubleLiteral) return expr.value;
  return null;
}

bool? _boolArg(Map<String, Expression> args, String name) {
  final expr = args[name];
  if (expr is BooleanLiteral) return expr.value;
  return null;
}

String? extractSingleArgumentAnnotationLiteral(
  AnnotatedNode node,
  String annotationName,
) {
  for (final ann in node.metadata) {
    if (_annotationName(ann) != annotationName) continue;

    final args = ann.arguments?.arguments;
    if (args == null || args.isEmpty) return null;

    final first = args.first;
    final expr = first is NamedExpression ? first.expression : first;
    return _cleanSource(expr.toSource());
  }
  return null;
}

String _cleanSource(String source) {
  var literal = source.trim();
  if (literal.startsWith('const ')) {
    literal = literal.substring(6).trimLeft();
  }
  return literal;
}

String _annotationName(Annotation annotation) {
  final name = annotation.name;
  return name is PrefixedIdentifier ? name.identifier.name : name.name;
}
