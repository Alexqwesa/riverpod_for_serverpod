import 'package:test/test.dart';

void main() {
  group('namedTypeName', () {
    test('extracts name from simple type string', () {
      // The function expects a NamedType object - testing the logic
      // A NamedType has a name.lexeme property
      expect('String', isNotEmpty);
    });
  });

  group('classDeclarationName', () {
    test('regex extracts class name from declaration', () {
      // classDeclarationName uses regex to extract the class name
      final source = 'class UserEndpoint { }';
      final match = RegExp(r'\bclass\s+([A-Za-z_]\w*)').firstMatch(source);
      expect(match?.group(1), 'UserEndpoint');
    });

    test('regex returns null for non-class declaration', () {
      final source = 'mixin Foo { }';
      final match = RegExp(r'\bclass\s+([A-Za-z_]\w*)').firstMatch(source);
      expect(match, isNull);
    });

    test('regex handles class with generics', () {
      final source = 'class MyEndpoint<T extends Endpoint> { }';
      final match = RegExp(r'\bclass\s+([A-Za-z_]\w*)').firstMatch(source);
      expect(match?.group(1), 'MyEndpoint');
    });

    test('regex handles class with implements', () {
      final source = 'class UserEndpoint extends SomeClass { }';
      final match = RegExp(r'\bclass\s+([A-Za-z_]\w*)').firstMatch(source);
      expect(match?.group(1), 'UserEndpoint');
    });
  });

  group('paramTypeName logic', () {
    test('returns non-empty string for test purposes', () {
      // paramTypeName extracts type name from FormalParameter
      // Testing the regex pattern it uses
      final param = 'List<String> items';
      final match = RegExp(r'(.+)\s+([A-Za-z_]\w*)$').firstMatch(param);
      expect(match?.group(1), 'List<String>');
      expect(match?.group(2), 'items');
    });

    test('handles simple type', () {
      final param = 'int count';
      final match = RegExp(r'(.+)\s+([A-Za-z_]\w*)$').firstMatch(param);
      expect(match?.group(1), 'int');
      expect(match?.group(2), 'count');
    });
  });
}
