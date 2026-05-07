import 'dart:convert';

import 'package:riverpod_for_serverpod_generator/src/types.dart';

String buildEndpointManifestCode(EndpointManifestMeta manifest) {
  return '''
const generatedEndpointManifest = <String, Object?>{
  'endpoints': <Map<String, Object?>>[
${manifest.endpoints.map(_endpointCode).join('\n')}
  ],
};
''';
}

String _endpointCode(EndpointManifestEntry endpoint) {
  return '''
    <String, Object?>{
      'name': ${_string(endpoint.name)},
      'methods': <Map<String, Object?>>[
${endpoint.methods.map(_methodCode).join('\n')}
      ],
    },''';
}

String _methodCode(MethodManifestEntry method) {
  return '''
        <String, Object?>{
          'name': ${_string(method.name)},
          'returnType': ${_string(method.returnType)},
          'positionalParams': <Map<String, Object?>>[
${method.positionalParams.map(_paramCode).join('\n')}
          ],
          'namedParams': <Map<String, Object?>>[
${method.namedParams.map(_paramCode).join('\n')}
          ],
          'cachedQuery': ${_cachedQueryCode(method.cachedQuery)},
          'mutationCommand': ${_mutationCommandCode(method.mutationCommand)},
          'validateStrings': <Map<String, Object?>>[
${method.validateStrings.map(_validateStringCode).join('\n')}
          ],
          'validateNumbers': <Map<String, Object?>>[
${method.validateNumbers.map(_validateNumberCode).join('\n')}
          ],
          'validateLists': <Map<String, Object?>>[
${method.validateLists.map(_validateListCode).join('\n')}
          ],
        },''';
}

String _paramCode(MyParamMeta param) {
  return '''
            <String, Object?>{
              'name': ${_string(param.name)},
              'type': ${_string(param.type)},
              'defaultValue': ${_nullableString(param.defaultValue)},
            },''';
}

String _cachedQueryCode(CachedQueryMeta? meta) {
  if (meta == null) return 'null';
  return '''
<String, Object?>{
            'entity': ${_string(meta.entity)},
            'idField': ${_string(meta.idField)},
            'maxItems': ${meta.maxItems},
            'ttl': ${_string(meta.ttl)},
            'secure': ${meta.secure},
            'byIdMethod': ${_nullableString(meta.byIdMethod)},
            'mergePolicy': ${_string(meta.mergePolicy)},
            'cacheVersion': ${meta.cacheVersion},
            'backgroundRefresh': ${meta.backgroundRefresh},
          }''';
}

String _mutationCommandCode(MutationCommandMeta? meta) {
  if (meta == null) return 'null';
  return '''
<String, Object?>{
            'affects': ${_string(meta.affects)},
            'idArg': ${_nullableString(meta.idArg)},
            'idField': ${_string(meta.idField)},
            'byIdMethod': ${_nullableString(meta.byIdMethod)},
            'invalidate': <Map<String, Object?>>[
${meta.invalidate.map(_invalidateCode).join('\n')}
            ],
            'optimistic': ${_string(meta.optimistic)},
            'retry': ${_string(meta.retry)},
            'refetch': ${_string(meta.refetch)},
            'idempotent': ${meta.idempotent},
            'idempotencyKeyArg': ${_nullableString(meta.idempotencyKeyArg)},
            'closeDialog': ${_string(meta.closeDialog)},
          }''';
}

String _invalidateCode(InvalidateMeta meta) {
  return '''
              <String, Object?>{
                'provider': ${_string(meta.provider)},
                'argFrom': ${_nullableString(meta.argFrom)},
                'family': ${meta.family},
              },''';
}

String _validateStringCode(ValidateStringMeta meta) {
  return '''
            <String, Object?>{
              'arg': ${_string(meta.arg)},
              'notEmpty': ${meta.notEmpty},
              'minLength': ${_nullableInt(meta.minLength)},
              'maxLength': ${_nullableInt(meta.maxLength)},
              'pattern': ${_nullableString(meta.pattern)},
            },''';
}

String _validateNumberCode(ValidateNumberMeta meta) {
  return '''
            <String, Object?>{
              'arg': ${_string(meta.arg)},
              'min': ${_nullableNum(meta.min)},
              'max': ${_nullableNum(meta.max)},
            },''';
}

String _validateListCode(ValidateListMeta meta) {
  return '''
            <String, Object?>{
              'arg': ${_string(meta.arg)},
              'notEmpty': ${meta.notEmpty},
              'minLength': ${_nullableInt(meta.minLength)},
              'maxLength': ${_nullableInt(meta.maxLength)},
            },''';
}

String _string(String value) => jsonEncode(value);

String _nullableString(String? value) =>
    value == null ? 'null' : _string(value);

String _nullableInt(int? value) => value?.toString() ?? 'null';

String _nullableNum(num? value) => value?.toString() ?? 'null';
