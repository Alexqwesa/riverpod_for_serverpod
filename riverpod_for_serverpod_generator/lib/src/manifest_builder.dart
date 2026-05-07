import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:riverpod_for_serverpod_generator/src/ast_helpers.dart';
import 'package:riverpod_for_serverpod_generator/src/read_annotations.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';

EndpointManifestMeta buildEndpointManifestFromSource({
  required String content,
  String? path,
}) {
  final parsed = parseString(content: content, path: path);
  final endpoints = <EndpointManifestEntry>[];

  for (final decl in parsed.unit.declarations.whereType<ClassDeclaration>()) {
    final className = classDeclarationName(decl);
    final superName = decl.extendsClause?.superclass is NamedType
        ? namedTypeName(decl.extendsClause!.superclass)
        : '';

    if (className.startsWith('_') ||
        decl.abstractKeyword != null ||
        !superName.endsWith('Endpoint') ||
        hasDoNotGenerateAnnotation(decl)) {
      continue;
    }

    final methods = <MethodManifestEntry>[];
    for (final member in decl.members.whereType<MethodDeclaration>()) {
      final method = _buildMethodManifest(member);
      if (method != null) methods.add(method);
    }

    if (methods.isNotEmpty) {
      endpoints.add(EndpointManifestEntry(name: className, methods: methods));
    }
  }

  return EndpointManifestMeta(endpoints);
}

MethodManifestEntry? _buildMethodManifest(MethodDeclaration member) {
  if (member.isGetter || member.isSetter) return null;

  final methodName = member.name.lexeme;
  final returnType = member.returnType?.toSource() ?? '';
  if (methodName.startsWith('_') ||
      !returnType.startsWith('Future') ||
      hasDoNotGenerateAnnotation(member)) {
    return null;
  }

  final parsedParams = _parseParametersFromMethod(member);
  if (!_hasServerpodSessionParameter(parsedParams)) return null;

  final positionalParams = <MyParamMeta>[];
  final namedParams = <MyParamMeta>[];
  for (var i = 1; i < parsedParams.length; i++) {
    final param = parsedParams[i];
    final meta = MyParamMeta(
      param.name,
      param.type,
      param.defaultValue ?? (param.type.trim().endsWith('?') ? 'null' : null),
    );
    if (param.isNamed) {
      namedParams.add(meta);
    } else {
      positionalParams.add(meta);
    }
  }

  return MethodManifestEntry(
    name: methodName,
    returnType: returnType,
    positionalParams: positionalParams,
    namedParams: namedParams,
    cachedQuery: extractCachedQueryMeta(member),
    mutationCommand: extractMutationCommandMeta(member),
    validateStrings: extractValidateStringMeta(member),
    validateNumbers: extractValidateNumberMeta(member),
    validateLists: extractValidateListMeta(member),
  );
}

bool _hasServerpodSessionParameter(List<_ParsedParam> params) {
  if (params.isEmpty) return false;
  final type = params.first.type;
  return type == 'Session' || type.endsWith('.Session');
}

List<_ParsedParam> _parseParametersFromMethod(MethodDeclaration method) {
  final parsed = <_ParsedParam>[];
  for (final parameter in method.parameters!.parameters) {
    final single = _parseSingleParam(parameter.toSource(), parameter.isNamed);
    if (single != null) parsed.add(single);
  }
  return parsed;
}

_ParsedParam? _parseSingleParam(String source, bool isNamed) {
  source = source.trim();
  if (source.startsWith('required ')) {
    source = source.substring('required '.length).trim();
  }
  if (source.startsWith('covariant ')) {
    source = source.substring('covariant '.length).trim();
  }
  if (source.startsWith('final ')) {
    source = source.substring('final '.length).trim();
  }

  String? defaultValue;
  final eqIndex = _topLevelIndexOf(source, '=');
  if (eqIndex >= 0) {
    defaultValue = source.substring(eqIndex + 1).trim();
    source = source.substring(0, eqIndex).trim();
  }

  final match = RegExp(r'(.+)\s+([A-Za-z_]\w*)$').firstMatch(source);
  if (match == null) return null;

  return _ParsedParam(
    name: match.group(2)!.trim(),
    type: match.group(1)!.trim(),
    isNamed: isNamed,
    defaultValue: defaultValue,
  );
}

int _topLevelIndexOf(String source, String char) {
  var angle = 0;
  var round = 0;
  var square = 0;
  var curly = 0;
  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    switch (ch) {
      case '<':
        angle++;
      case '>':
        if (angle > 0) angle--;
      case '(':
        round++;
      case ')':
        if (round > 0) round--;
      case '[':
        square++;
      case ']':
        if (square > 0) square--;
      case '{':
        curly++;
      case '}':
        if (curly > 0) curly--;
    }
    if (ch == char && angle == 0 && round == 0 && square == 0 && curly == 0) {
      return i;
    }
  }
  return -1;
}

class _ParsedParam {
  const _ParsedParam({
    required this.name,
    required this.type,
    required this.isNamed,
    this.defaultValue,
  });

  final String name;
  final String type;
  final bool isNamed;
  final String? defaultValue;
}
