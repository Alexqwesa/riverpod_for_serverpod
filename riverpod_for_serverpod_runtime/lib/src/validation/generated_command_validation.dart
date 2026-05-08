/// Thrown when generated mutation command validation fails before the network
/// call. Not a connection error — callers should not enqueue retry.
class GeneratedCommandValidationException implements Exception {
  GeneratedCommandValidationException(this.message, {this.arg});

  final String message;
  final String? arg;

  @override
  String toString() => message;
}

void validateGeneratedString(
  String argName,
  String? value, {
  bool notEmpty = false,
  int? minLength,
  int? maxLength,
  String? pattern,
}) {
  if (value == null) {
    if (notEmpty || minLength != null || maxLength != null || pattern != null) {
      throw GeneratedCommandValidationException(
        '$argName must not be null.',
        arg: argName,
      );
    }
    return;
  }

  if (notEmpty && value.isEmpty) {
    throw GeneratedCommandValidationException(
      '$argName must not be empty.',
      arg: argName,
    );
  }

  if (minLength != null && value.length < minLength) {
    throw GeneratedCommandValidationException(
      '$argName must be at least $minLength characters.',
      arg: argName,
    );
  }

  if (maxLength != null && value.length > maxLength) {
    throw GeneratedCommandValidationException(
      '$argName must be at most $maxLength characters.',
      arg: argName,
    );
  }

  if (pattern != null && pattern.isNotEmpty) {
    if (!RegExp(pattern).hasMatch(value)) {
      throw GeneratedCommandValidationException(
        '$argName does not match the required pattern.',
        arg: argName,
      );
    }
  }
}

void validateGeneratedNumber(
  String argName,
  num? value, {
  num? min,
  num? max,
}) {
  if (value == null) {
    if (min != null || max != null) {
      throw GeneratedCommandValidationException(
        '$argName must not be null.',
        arg: argName,
      );
    }
    return;
  }

  if (min != null && value < min) {
    throw GeneratedCommandValidationException(
      '$argName must be >= $min.',
      arg: argName,
    );
  }

  if (max != null && value > max) {
    throw GeneratedCommandValidationException(
      '$argName must be <= $max.',
      arg: argName,
    );
  }
}

void validateGeneratedIterable(
  String argName,
  Object? value, {
  bool notEmpty = false,
  int? minLength,
  int? maxLength,
}) {
  if (value == null) {
    if (notEmpty || minLength != null) {
      throw GeneratedCommandValidationException(
        '$argName must not be null.',
        arg: argName,
      );
    }
    return;
  }

  if (value is! Iterable) {
    throw GeneratedCommandValidationException(
      '$argName must be an Iterable.',
      arg: argName,
    );
  }

  final len = value is List ? value.length : value.toList().length;

  if (notEmpty && len == 0) {
    throw GeneratedCommandValidationException(
      '$argName must not be empty.',
      arg: argName,
    );
  }

  if (minLength != null && len < minLength) {
    throw GeneratedCommandValidationException(
      '$argName must contain at least $minLength items.',
      arg: argName,
    );
  }

  if (maxLength != null && len > maxLength) {
    throw GeneratedCommandValidationException(
      '$argName must contain at most $maxLength items.',
      arg: argName,
    );
  }
}
