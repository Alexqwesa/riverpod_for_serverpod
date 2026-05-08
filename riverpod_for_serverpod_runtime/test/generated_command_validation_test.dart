import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('validateGeneratedString', () {
    test('notEmpty rejects empty', () {
      expect(
        () => validateGeneratedString('s', '', notEmpty: true),
        throwsA(isA<GeneratedCommandValidationException>()),
      );
    });

    test('maxLength rejects long string', () {
      expect(
        () => validateGeneratedString('s', 'abcd', maxLength: 3),
        throwsA(isA<GeneratedCommandValidationException>()),
      );
    });

    test('pattern rejects non-match', () {
      expect(
        () => validateGeneratedString('s', 'abc', pattern: r'^\d+$'),
        throwsA(isA<GeneratedCommandValidationException>()),
      );
    });
  });

  group('validateGeneratedNumber', () {
    test('range', () {
      expect(
        () => validateGeneratedNumber('n', 0, min: 1),
        throwsA(isA<GeneratedCommandValidationException>()),
      );
    });
  });

  group('validateGeneratedIterable', () {
    test('notEmpty rejects empty list', () {
      expect(
        () => validateGeneratedIterable('xs', <int>[], notEmpty: true),
        throwsA(isA<GeneratedCommandValidationException>()),
      );
    });
  });
}
