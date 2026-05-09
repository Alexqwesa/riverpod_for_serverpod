import 'package:riverpod_for_serverpod_generator/src/riverpod_pubspec.dart';
import 'package:test/test.dart';

void main() {
  group('inferEmitProviderRetry', () {
    test('true when no riverpod constraint', () {
      expect(
        inferEmitProviderRetry('''
name: x
dependencies:
  meta: any
'''),
        isTrue,
      );
    });

    test('false when only Riverpod 2 caret constraint', () {
      expect(
        inferEmitProviderRetry('''
dependencies:
  riverpod: ^2.6.1
'''),
        isFalse,
      );
    });

    test('true when constraint allows 3.0.0', () {
      expect(
        inferEmitProviderRetry('''
dependencies:
  riverpod: ">=2.0.0 <5.0.0"
'''),
        isTrue,
      );
    });

    test('true when flutter_riverpod allows 3', () {
      expect(
        inferEmitProviderRetry('''
dependencies:
  flutter_riverpod: ^3.0.0
'''),
        isTrue,
      );
    });

    test('any listed dep allowing v3 wins over a v2-only dep', () {
      expect(
        inferEmitProviderRetry('''
dependencies:
  riverpod: ^2.0.0
dev_dependencies:
  riverpod: ^3.0.0
'''),
        isTrue,
      );
    });
  });
}
