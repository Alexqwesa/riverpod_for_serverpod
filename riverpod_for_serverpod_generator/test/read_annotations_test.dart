import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:riverpod_for_serverpod_generator/src/read_annotations.dart';
import 'package:test/test.dart';

void main() {
  group('extractCacheTtlLiteral', () {
    test('extracts simple duration literal', () {
      const source = '''
@CacheTtl(Duration(minutes: 5))
Future<Data> getData() {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractCacheTtlLiteral(node), 'Duration(minutes: 5)');
    });

    test('extracts duration with const keyword', () {
      const source = '''
@CacheTtl(const Duration(hours: 1))
Future<Data> getData() {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractCacheTtlLiteral(node), 'Duration(hours: 1)');
    });

    test('extracts duration with seconds', () {
      const source = '''
@CacheTtl(Duration(seconds: 30))
Future<Data> getData() {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractCacheTtlLiteral(node), 'Duration(seconds: 30)');
    });

    test('returns null when no CacheTtl annotation', () {
      const source = '''
Future<Data> getData() {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractCacheTtlLiteral(node), isNull);
    });

    test('handles prefixed annotation name', () {
      const source = '''
@CacheTtl(Duration(days: 1))
Future<Data> getData() {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractCacheTtlLiteral(node), 'Duration(days: 1)');
    });
  });

  group('extractTimeoutLiteral', () {
    test('extracts timeout duration literal', () {
      const source = '''
@Timeout(Duration(minutes: 2))
Future<Data> getData() {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractTimeoutLiteral(node), 'Duration(minutes: 2)');
    });
  });

  group('extractInvalidateTargets', () {
    test('extracts endpoint targets from RefInvalidate', () {
      const source = '''
@RefInvalidate(['AdminEndpoint', 'UserSummaryEndpoint'])
Future<void> sync() async {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(
        extractInvalidateTargets(node),
        ['AdminEndpoint', 'UserSummaryEndpoint'],
      );
      expect(extractInvalidateIncludesSelf(node), isTrue);
    });

    test('extracts includeSelf flag from RefInvalidate', () {
      const source = '''
@RefInvalidate(['BankBalanceEndpoint'], includeSelf: false)
Future<void> sync() async {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractInvalidateTargets(node), ['BankBalanceEndpoint']);
      expect(extractInvalidateIncludesSelf(node), isFalse);
    });
  });

  group('hasDoNotGenerateAnnotation', () {
    test('detects DoNotGenerate annotation', () {
      const source = '''
@DoNotGenerate()
Future<void> internalOnly() async {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(hasDoNotGenerateAnnotation(node), isTrue);
    });
  });
}
