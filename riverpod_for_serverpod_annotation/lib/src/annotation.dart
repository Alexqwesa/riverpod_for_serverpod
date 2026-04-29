import 'package:meta/meta.dart';

@immutable
class CacheTtl {
  final Duration value;

  const CacheTtl([this.value = const Duration(minutes: 3)]);
}

@immutable
class Timeout {
  final Duration value;

  const Timeout([this.value = const Duration(seconds: 30)]);
}

@immutable
class RefInvalidate {
  final List<String> endpoints;
  final bool includeSelf;

  const RefInvalidate(this.endpoints, {this.includeSelf = true});
}

@immutable
class DoNotGenerate {
  const DoNotGenerate();
}
