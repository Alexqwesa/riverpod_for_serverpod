import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

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

Duration readCacheTtlOrDefault(Element element, {Duration orDefault = const Duration(minutes: 3)}) {
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
    var literal = expr.toSource();
    if (literal.startsWith('const ')) {
      literal = literal.substring(6).trimLeft();
    }
    return literal;
  }
  return null;
}

String _annotationName(Annotation annotation) {
  final name = annotation.name;
  return name is PrefixedIdentifier ? name.identifier.name : name.name;
}
