import 'dart:async';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:recase/recase.dart';
import 'package:riverpod_for_serverpod_generator/src/ast_helpers.dart';
import 'package:riverpod_for_serverpod_generator/src/build_cached_query_notifier.dart';
import 'package:riverpod_for_serverpod_generator/src/build_mutation_command.dart';
import 'package:riverpod_for_serverpod_generator/src/build_provider_field.dart';
import 'package:riverpod_for_serverpod_generator/src/build_provider_invalidator.dart';
import 'package:riverpod_for_serverpod_generator/src/build_provider_variant.dart';
import 'package:riverpod_for_serverpod_generator/src/cached_query_codegen.dart';
import 'package:riverpod_for_serverpod_generator/src/diagnostics.dart';
import 'package:riverpod_for_serverpod_generator/src/manifest_builder.dart';
import 'package:riverpod_for_serverpod_generator/src/manifest_emitter.dart';
import 'package:riverpod_for_serverpod_generator/src/read_annotations.dart';
import 'package:riverpod_for_serverpod_generator/src/riverpod_pubspec.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';

const _providerWatchesCode = '''
ref
  ..watch(refUpdateAllGeneratedProviders)
  ..watch(refUpdateAll);
''';

String swrNotifierWatchesCode(String refInnerProviderName) => '''
ref
  ..watch(refUpdateAllGeneratedProviders)
  ..watch($refInnerProviderName.refUpdateAll);
''';

/// [emitProviderRetry] matches [inferEmitProviderRetry]: true when pubspec allows Riverpod 3+.
///
/// Riverpod 3: guard with [Ref.mounted]. Riverpod 2: no `mounted`; use [StateError] try/catch
/// after async gaps with `autoDispose`.
String emittedRefCacheForExtension({required bool emitProviderRetry}) {
  if (emitProviderRetry) {
    return '''
extension RefCacheForExtension on Ref {
  void cacheFor(Duration duration) {
    if (!mounted) return;
    final link = keepAlive();
    final timer = Timer(duration, link.close);

    onDispose(timer.cancel);
  }
}
''';
  }
  return '''
extension RefCacheForExtension on Ref {
  void cacheFor(Duration duration) {
    try {
      final link = keepAlive();
      final timer = Timer(duration, link.close);

      onDispose(timer.cancel);
    } on StateError {
      // Provider already disposed (e.g. autoDispose after an async gap on Riverpod 2).
    }
  }
}
''';
}

class RefEndpointBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
        'pubspec.yaml': ['lib/src/generated/ref_endpoints.dart'],
      };

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final serverPackageName = buildStep.inputId.package;
    final clientPackageName = deriveClientPackageName(serverPackageName);
    final endpoints = <_EndpointMeta>[];
    final manifestEndpoints = <EndpointManifestEntry>[];

    await for (final id in buildStep.findAssets(Glob('lib/**.dart'))) {
      if (id.path.contains('/generated/')) continue;

      final content = await buildStep.readAsString(id);
      manifestEndpoints.addAll(
        buildEndpointManifestFromSource(
          content: content,
          path: id.path,
        ).endpoints,
      );
      final parsed = parseString(content: content, path: id.path);
      final unit = parsed.unit;

      for (final decl in unit.declarations.whereType<ClassDeclaration>()) {
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

        final methods = <MyMethodMeta>[];
        for (final member in decl.members.whereType<MethodDeclaration>()) {
          if (member.isGetter || member.isSetter) continue;

          final methodName = member.name.lexeme;
          final returnType = member.returnType?.toSource() ?? '';
          if (!returnType.startsWith('Future')) continue;
          if (methodName.startsWith('_') ||
              hasDoNotGenerateAnnotation(member)) {
            continue;
          }

          final parsedParams = _parseParametersFromMethod(member);
          if (!_hasServerpodSessionParameter(parsedParams)) continue;

          final positionalParams = <MyParamMeta>[];
          final namedParams = <MyParamMeta>[];

          for (var i = 1; i < parsedParams.length; i++) {
            final param = parsedParams[i];
            if (param.isNamed) {
              namedParams.add(
                MyParamMeta(
                  param.name,
                  param.type,
                  param.defaultValue ??
                      (param.type.trim().endsWith('?') ? 'null' : null),
                ),
              );
            } else {
              positionalParams.add(
                MyParamMeta(
                  param.name,
                  param.type,
                  param.defaultValue ??
                      (param.type.trim().endsWith('?') ? 'null' : null),
                ),
              );
            }
          }

          methods.add(
            MyMethodMeta(
              methodName,
              returnType,
              positionalParams,
              namedParams,
              positionalParams.isNotEmpty,
              namedParams.isNotEmpty,
              cacheTtl:
                  extractCacheTtlLiteral(member) ?? 'Duration(minutes: 3)',
              innerProviderName: 'Ref$className',
              timeout: extractTimeoutLiteral(member),
              invalidateTargets:
                  normalizeHookTargets(extractInvalidateTargets(member)),
              includeSelfInHook: extractInvalidateIncludesSelf(member),
              cachedQuery: extractCachedQueryMeta(member),
              mutationCommand: extractMutationCommandMeta(member),
              validateStrings: extractValidateStringMeta(member),
              validateNumbers: extractValidateNumberMeta(member),
              validateLists: extractValidateListMeta(member),
            ),
          );
        }

        if (methods.isNotEmpty) {
          endpoints.add(_EndpointMeta(className, methods));
        }
      }
    }

    if (endpoints.isEmpty) return;

    final emitProviderRetry =
        inferEmitProviderRetry(await buildStep.readAsString(buildStep.inputId));

    final manifest = EndpointManifestMeta(manifestEndpoints);
    for (final diagnostic in validateEndpointManifest(manifest)) {
      final message = diagnostic.displayMessage;
      switch (diagnostic.severity) {
        case ManifestDiagnosticSeverity.warning:
          log.warning(message);
        case ManifestDiagnosticSeverity.error:
          log.severe(message);
      }
    }

    final entityCacheTemplates = _collectEntityCacheTemplates(endpoints);
    final methodToClientField = _collectMethodToClientField(endpoints);

    final code = _buildLibrary(
      endpoints: endpoints,
      manifest: manifest,
      clientPackageName: clientPackageName,
      emitProviderRetry: emitProviderRetry,
      entityCacheTemplates: entityCacheTemplates,
      methodToClientField: methodToClientField,
    );
    final out = AssetId(
      buildStep.inputId.package,
      'lib/src/generated/ref_endpoints.dart',
    );
    await buildStep.writeAsString(out, code);
  }
}

String deriveClientPackageName(String serverPackageName) {
  if (serverPackageName.endsWith('_server')) {
    return '${serverPackageName.substring(0, serverPackageName.length - 7)}_client';
  }
  return '${serverPackageName}_client';
}

Map<String, EntityCacheTemplate> _collectEntityCacheTemplates(
  List<_EndpointMeta> endpoints,
) {
  final map = <String, EntityCacheTemplate>{};
  for (final endpoint in endpoints) {
    for (final m in endpoint.methods) {
      final cq = m.cachedQuery;
      if (cq == null) continue;
      final shape = parseCachedQueryReturnType(m.unwrappedReturnType);
      if (shape == null) continue;
      final key = cq.entity;
      if (map.containsKey(key)) continue;
      map[key] = EntityCacheTemplate(
        elementType: shape.elementType,
        entityTypeKey: cq.entity,
        idField: cq.idField,
        cacheVersion: cq.cacheVersion,
        maxItems: cq.maxItems,
        secure: cq.secure,
        byIdMethod: cq.byIdMethod,
      );
    }
  }
  return map;
}

Map<String, String> _collectMethodToClientField(List<_EndpointMeta> endpoints) {
  final map = <String, String>{};
  for (final ep in endpoints) {
    final cf = _clientFieldName(ep.name);
    for (final m in ep.methods) {
      map[m.name] = cf;
    }
  }
  return map;
}

List<String> collectRequiredDartImports(String emittedCode) {
  final imports = <String>[];

  if (_needsConvertImport(emittedCode)) {
    imports.add('dart:convert');
  }
  if (_needsTypedDataImport(emittedCode)) {
    imports.add('dart:typed_data');
  }

  return imports;
}

bool _needsConvertImport(String emittedCode) {
  return emittedCode.contains(
    RegExp(r'\b(jsonDecode|jsonEncode|utf8|base64)\b'),
  );
}

bool _needsTypedDataImport(String emittedCode) {
  return emittedCode.contains(RegExp(r'\b(ByteData|Uint8List)\b'));
}

List<String> normalizeHookTargets(Iterable<String> targets) {
  final normalized = <String>{};
  for (final raw in targets) {
    var value = raw.trim();
    if (value.isEmpty) continue;
    if (!value.startsWith('Ref')) value = 'Ref$value';
    normalized.add(value);
  }
  return normalized.toList(growable: false);
}

bool _hasServerpodSessionParameter(List<_ParsedParam> params) {
  if (params.isEmpty) return false;
  final type = params.first.type;
  return type == 'Session' || type.endsWith('.Session');
}

String _buildLibrary({
  required List<_EndpointMeta> endpoints,
  required EndpointManifestMeta manifest,
  required String clientPackageName,
  required bool emitProviderRetry,
  Map<String, EntityCacheTemplate> entityCacheTemplates = const {},
  Map<String, String> methodToClientField = const {},
}) {
  final baseDartImports = <String>['dart:async'];
  final basePackageImports = <String>[
    'package:riverpod/riverpod.dart',
    'package:riverpod/misc.dart',
    'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart',
    'package:$clientPackageName/src/protocol/protocol.dart',
    'package:serverpod_auth_client/serverpod_auth_client.dart',
  ];

  final library = Library((b) {
    b.body.add(Code(buildEndpointManifestCode(manifest)));
    b.body.add(
      Code('''
typedef Reader = T Function<T>(ProviderListenable<T> provider);
typedef ProviderInvalidator = void Function(ProviderOrFamily provider);

final clientProvider = Provider<Client>((ref) {
  const serverUrlFromEnv = String.fromEnvironment('SERVER_URL');
  final serverUrl =
      serverUrlFromEnv.isEmpty ? 'http://localhost:8080/' : serverUrlFromEnv;
  return Client(serverUrl);
});

class Counter extends Notifier<int> {
  @override
  int build() => 0;

  void updateAll() => state++;
}

final refUpdateAllGeneratedProviders = NotifierProvider<Counter, int>(
  Counter.new,
);

${emitProviderRetry ? 'Duration? _noProviderRetry(int retryCount, Object error) => null;\n\n' : ''}${emittedRefCacheForExtension(emitProviderRetry: emitProviderRetry)}'''),
    );

    for (final endpoint in endpoints) {
      final clientField = _clientFieldName(endpoint.name);
      for (final method
          in endpoint.methods.where((m) => m.mutationCommand == null)) {
        final rawReturn = method.returnType;
        final unwrappedReturnType =
            rawReturn.startsWith('Future<') && rawReturn.endsWith('>')
                ? rawReturn.substring(7, rawReturn.length - 1)
                : rawReturn;
        final notifierSrc = buildCachedQueryNotifierSource(
          m: method,
          clientField: clientField,
          returnType: unwrappedReturnType,
          host: swrNotifierHostParams(method),
          refWatchBlock: swrNotifierWatchesCode(method.innerProviderName),
        );
        if (notifierSrc != null) {
          b.body.add(Code(notifierSrc));
        }
      }
    }

    b.body.addAll(
      endpoints.map((endpoint) {
        final endpointClass = endpoint.name;
        final clientField = _clientFieldName(endpointClass);

        return Class((cb) {
          cb
            ..name = 'Ref$endpointClass'
            ..abstract = true
            ..constructors.add(Constructor((c) => c..constant = true))
            ..methods.add(
              Method((mb) {
                mb
                  ..name = 'updateAll'
                  ..static = true
                  ..returns = refer('void')
                  ..requiredParameters.add(
                    Parameter(
                      (p) => p
                        ..name = 'read'
                        ..type = refer('Reader'),
                    ),
                  )
                  ..body = const Code(
                    'read(refUpdateAll.notifier).updateAll();',
                  );
              }),
            )
            ..fields.add(
              Field((fb) {
                fb
                  ..name = 'refUpdateAll'
                  ..static = true
                  ..modifier = FieldModifier.final$
                  ..type = refer(
                    'NotifierProvider<Counter, int>',
                    'package:riverpod/riverpod.dart',
                  )
                  ..assignment = Code(
                    'NotifierProvider<Counter, int>(Counter.new)',
                  );
              }),
            )
            ..fields.addAll(
              endpoint.methods
                  .where((m) => m.mutationCommand == null)
                  .expand((method) {
                final rawReturn = method.returnType;
                final unwrappedReturnType =
                    rawReturn.startsWith('Future<') && rawReturn.endsWith('>')
                        ? rawReturn.substring(7, rawReturn.length - 1)
                        : rawReturn;

                final mainField = buildProviderField(
                  method,
                  unwrappedReturnType,
                  _providerWatchesCode,
                  clientField,
                  emitProviderRetry: emitProviderRetry,
                );
                final variants = buildProviderVariants(
                  method,
                  unwrappedReturnType,
                  '',
                  clientField,
                  'Ref$endpointClass',
                  emitProviderRetry: emitProviderRetry,
                );
                return <Field>[mainField, ...variants];
              }),
            )
            ..methods.addAll(
              endpoint.methods
                  .where((m) => m.mutationCommand == null)
                  .expand(buildProviderInvalidatorMethods),
            )
            ..methods.addAll(
              endpoint.methods.map(
                (method) => _buildInvalidateHookMethod(
                  currentEndpoint: endpointClass,
                  method: method,
                ),
              ),
            );
        });
      }),
    );
    b.body.addAll(
      endpoints.expand((endpoint) {
        final endpointClass = endpoint.name;
        final clientField = _clientFieldName(endpointClass);
        final mutationMethods =
            endpoint.methods.where((m) => m.mutationCommand != null).toList();
        if (mutationMethods.isEmpty) return <Code>[];
        return [
          Code(
            buildMutationCommandsClass(
              endpointClassName: endpointClass,
              clientField: clientField,
              mutationMethods: mutationMethods,
              entityCacheTemplates: entityCacheTemplates,
              methodToClientField: methodToClientField,
            ),
          ),
          Code(
            buildMutationControllerSource(
              endpointClassName: endpointClass,
              mutationMethods: mutationMethods,
            ),
          ),
        ];
      }),
    );
    final replayBootstrap = _buildMutationRetryReplayBootstrap(endpoints);
    if (replayBootstrap.isNotEmpty) {
      b.body.add(Code(replayBootstrap));
    }
  });

  final emitted = library.accept(DartEmitter()).toString();
  final extraDartImports = collectRequiredDartImports(emitted);
  final requiredImports = [
    ...baseDartImports,
    ...extraDartImports,
    ...basePackageImports,
  ];

  final fullSource = '''
// GENERATED - DO NOT MODIFY
// @dart=3.0

${requiredImports.map((importPath) => "import '$importPath';").join('\n')}

$emitted
''';
  try {
    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(fullSource);
  } catch (_) {
    return fullSource;
  }
}

Method _buildInvalidateHookMethod({
  required String currentEndpoint,
  required MyMethodMeta method,
}) {
  final methodName = 'invalidateAfter${ReCase(method.name).pascalCase}';
  final targets = <String>{
    if (method.includeSelfInHook) 'Ref$currentEndpoint',
    ...method.invalidateTargets,
  };

  final body = StringBuffer();
  for (final target in targets) {
    body.writeln('$target.updateAll(read);');
  }

  return Method((mb) {
    mb
      ..name = methodName
      ..static = true
      ..returns = refer('void')
      ..requiredParameters.add(
        Parameter(
          (p) => p
            ..name = 'read'
            ..type = refer('Reader'),
        ),
      )
      ..body = Code(body.toString());
  });
}

String _buildMutationRetryReplayBootstrap(List<_EndpointMeta> endpoints) {
  final buf = StringBuffer();
  buf.writeln('bool _riverpodForServerpodRegisterMutationReplays() {');
  var any = false;
  for (final ep in endpoints) {
    for (final m in ep.methods) {
      final meta = m.mutationCommand;
      if (meta == null) continue;
      if (!meta.idempotent || meta.retry == 'RetryPolicy.none') continue;
      any = true;
      buf.writeln(
        "  MutationRetryReplayRegistry.register(r'${ep.name}.${m.name}', (read, args) async {",
      );
      buf.writeln(
        '    await Ref${ep.name}Commands.${m.name}(read${_replayMutationArgsFromMap(m)});',
      );
      buf.writeln('  });');
    }
  }
  if (!any) return '';
  buf.writeln('  return true;');
  buf.writeln('}');
  buf.writeln('final _riverpodForServerpodMutationReplayReady = '
      '_riverpodForServerpodRegisterMutationReplays();');
  return buf.toString();
}

String _replayMutationArgsFromMap(MyMethodMeta m) {
  if (!m.hasPositionalParams && !m.hasNamedParams) return '';
  final parts = <String>[
    for (final p in m.positionalParams) _castArgReadForMutationReplay(p),
    for (final p in m.namedParams)
      '${p.name}: ${_castArgReadForMutationReplay(p)}',
  ];
  return ', ${parts.join(', ')}';
}

String _castArgReadForMutationReplay(MyParamMeta p) {
  final key = "args[r'${p.name}']";
  final t = p.type.replaceAll(' ', '');
  if (t == 'int') return '$key as int';
  if (t == 'int?') return '$key as int?';
  if (t == 'double') return '($key as num).toDouble()';
  if (t == 'double?') {
    return '$key != null ? ($key! as num).toDouble() : null';
  }
  if (t == 'String') return '$key as String';
  if (t == 'String?') return '$key as String?';
  if (t == 'bool') return '$key as bool';
  if (t == 'bool?') return '$key as bool?';
  if (t == 'DateTime') return 'DateTime.parse($key! as String)';
  if (t == 'DateTime?') {
    return '$key != null ? DateTime.parse($key! as String) : null';
  }
  return '$key as ${p.type}';
}

String _clientFieldName(String endpointClass) {
  final baseName = endpointClass.replaceAll(RegExp(r'Endpoint$'), '');
  return ReCase(baseName).camelCase;
}

class _EndpointMeta {
  const _EndpointMeta(this.name, this.methods);

  final String name;
  final List<MyMethodMeta> methods;
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

List<_ParsedParam> _parseParametersFromMethod(MethodDeclaration method) {
  final parsed = <_ParsedParam>[];
  for (final parameter in method.parameters!.parameters) {
    final single = _parseSingleParam(parameter.toSource(), parameter.isNamed);
    if (single != null) {
      parsed.add(single);
    }
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
