import 'package:riverpod_for_serverpod_generator/src/build_provider_field.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';

void main() {
  final m = MyMethodMeta('getScopes', 'List<String>', [], [], false, false, "RefTest");
  final f = buildProviderField(m, 'List<String>', '', 'user');
  print(f);
}
