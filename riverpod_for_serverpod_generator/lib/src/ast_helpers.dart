import 'package:analyzer/dart/ast/ast.dart';

String namedTypeName(NamedType t) {
  return t.name.lexeme;
}

String classDeclarationName(ClassDeclaration decl) {
  final match = RegExp(r'\bclass\s+([A-Za-z_]\w*)').firstMatch(decl.toSource());
  return match?.group(1) ?? '';
}

String? paramTypeName(FormalParameter p) {
  // unwrap defaulted param
  if (p is DefaultFormalParameter) p = p.parameter;

  if (p is SimpleFormalParameter) {
    final t = p.type;
    if (t is NamedType) {
      return namedTypeName(t);
    }
  }
  return null;
}
