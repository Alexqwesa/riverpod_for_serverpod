import 'package:code_builder/code_builder.dart';
import 'package:recase/recase.dart';
import 'package:riverpod_for_serverpod_generator/src/build_provider_field.dart';
import 'package:riverpod_for_serverpod_generator/src/build_provider_variant.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';

/// Generates exact and broad invalidators for providers inside one generated
/// `Ref*Endpoint` class.
///
/// Variant invalidators invalidate the canonical provider instance because the
/// generated variants are only wrappers that watch the canonical provider.
Iterable<Method> buildProviderInvalidatorMethods(MyMethodMeta m) sync* {
  yield _buildCanonicalExactInvalidator(m);
  yield _buildCanonicalBroadInvalidator(m);

  for (final variant in buildProviderVariantSpecs(m)) {
    yield _buildVariantToCanonicalArgsMapper(m, variant);
    yield _buildVariantInvalidator(m, variant);
  }
}

Method _buildCanonicalExactInvalidator(MyMethodMeta m) {
  final family = _canonicalUsesFamily(m);
  final body = family ? 'invalidate(${m.name}(args));' : 'invalidate(${m.name});';

  return Method((mb) {
    mb
      ..name = '${m.name}Invalidate'
      ..static = true
      ..returns = refer('void')
      ..requiredParameters.add(
        Parameter(
          (p) => p
            ..name = 'invalidate'
            ..type = refer('ProviderInvalidator'),
        ),
      );

    if (family) {
      mb.requiredParameters.add(
        Parameter(
          (p) => p
            ..name = 'args'
            ..type = refer(_canonicalArgType(m)),
        ),
      );
    }

    mb.body = Code(body);
  });
}

Method _buildCanonicalBroadInvalidator(MyMethodMeta m) {
  return Method((mb) {
    mb
      ..name = '${m.name}InvalidateAll'
      ..static = true
      ..returns = refer('void')
      ..requiredParameters.add(
        Parameter(
          (p) => p
            ..name = 'invalidate'
            ..type = refer('ProviderInvalidator'),
        ),
      )
      ..body = Code('invalidate(${m.name});');
  });
}

Method _buildVariantToCanonicalArgsMapper(
  MyMethodMeta m,
  ProviderVariantSpec variant,
) {
  final canonicalArgType = _canonicalArgType(m);
  final methodName = '${variant.name}To${ReCase(m.name).pascalCase}Args';

  return Method((mb) {
    mb
      ..name = methodName
      ..static = true
      ..returns = refer(canonicalArgType);

    if (variant.shouldUseFamily) {
      mb.requiredParameters.add(
        Parameter(
          (p) => p
            ..name = 'args'
            ..type = refer(variant.argType),
        ),
      );
    }

    mb.body = Code(_variantMapperBody(variant));
  });
}

String _variantMapperBody(ProviderVariantSpec variant) {
  if (!variant.shouldUseFamily) {
    return 'return ${variant.canonicalArgsExpression};';
  }
  final destructure =
      variant.argDestructureCode.replaceAll('= arg;', '= args;');
  return '''
    $destructure
    return ${variant.canonicalArgsExpression};
''';
}

Method _buildVariantInvalidator(
  MyMethodMeta m,
  ProviderVariantSpec variant,
) {
  final mapperName = '${variant.name}To${ReCase(m.name).pascalCase}Args';
  final mapperCall = variant.shouldUseFamily ? '$mapperName(args)' : '$mapperName()';

  return Method((mb) {
    mb
      ..name = '${variant.name}Invalidate'
      ..static = true
      ..returns = refer('void')
      ..requiredParameters.add(
        Parameter(
          (p) => p
            ..name = 'invalidate'
            ..type = refer('ProviderInvalidator'),
        ),
      );

    if (variant.shouldUseFamily) {
      mb.requiredParameters.add(
        Parameter(
          (p) => p
            ..name = 'args'
            ..type = refer(variant.argType),
        ),
      );
    }

    mb.body = Code('invalidate(${m.name}($mapperCall));');
  });
}

bool _canonicalUsesFamily(MyMethodMeta m) =>
    m.hasPositionalParams || m.hasNamedParams;

String _canonicalArgType(MyMethodMeta m) {
  if (!m.hasPositionalParams && !m.hasNamedParams) {
    return 'Never';
  }
  if (m.positionalParams.length == 1 && m.namedParams.isEmpty) {
    return m.positionalParams.first.type;
  }
  if (m.positionalParams.isEmpty && m.namedParams.length == 1) {
    return m.namedParams.first.type;
  }
  return buildRecordTypeAndDestructure(m).recordType;
}
