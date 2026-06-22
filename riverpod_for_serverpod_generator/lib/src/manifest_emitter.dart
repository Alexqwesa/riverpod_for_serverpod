import 'dart:convert';

import 'package:riverpod_for_serverpod_generator/src/types.dart';

String buildEndpointManifestCode(EndpointManifestMeta manifest) {
  return '''
const generatedEndpointManifest = EndpointManifest(
  endpoints: [
${manifest.endpoints.map(_endpointCode).join('\n')}
  ],
);
''';
}

String _endpointCode(EndpointManifestEntry endpoint) {
  return '''
    EndpointInfo(
      name: ${_string(endpoint.name)},
      methods: [
${endpoint.methods.map(_methodCode).join('\n')}
      ],
    ),''';
}

String _methodCode(MethodManifestEntry method) {
  return '''
        MethodInfo(
          name: ${_string(method.name)},
          returnType: ${_string(method.returnType)},
          positionalParams: [
${method.positionalParams.map(_paramCode).join('\n')}
          ],
          namedParams: [
${method.namedParams.map(_paramCode).join('\n')}
          ],
          cachedQuery: ${_cachedQueryCode(method.cachedQuery)},
          mutationCommand: ${_mutationCommandCode(method.mutationCommand)},
          validateStrings: [
${method.validateStrings.map(_validateStringCode).join('\n')}
          ],
          validateNumbers: [
${method.validateNumbers.map(_validateNumberCode).join('\n')}
          ],
          validateLists: [
${method.validateLists.map(_validateListCode).join('\n')}
          ],
        ),''';
}

String _paramCode(MyParamMeta param) {
  return '''
            ParamInfo(
              name: ${_string(param.name)},
              type: ${_string(param.type)},
              defaultValue: ${_nullableString(param.defaultValue)},
            ),''';
}

String _cachedQueryCode(CachedQueryMeta? meta) {
  if (meta == null) return 'null';
  return '''
CachedQueryInfo(
            entity: ${_string(meta.entity)},
            idField: ${_string(meta.idField)},
            maxItems: ${meta.maxItems},
            ttl: ${meta.ttl},
            secure: ${meta.secure},
            byIdMethod: ${_nullableString(meta.byIdMethod)},
            mergePolicy: ${meta.mergePolicy},
            cacheVersion: ${meta.cacheVersion},
            backgroundRefresh: ${meta.backgroundRefresh},
          )''';
}

String _mutationCommandCode(MutationCommandMeta? meta) {
  if (meta == null) return 'null';
  return '''
MutationCommandInfo(
            affects: ${_string(meta.affects)},
            idArg: ${_nullableString(meta.idArg)},
            idField: ${_string(meta.idField)},
            byIdMethod: ${_nullableString(meta.byIdMethod)},
            invalidate: [
${meta.invalidate.map(_invalidateCode).join('\n')}
            ],
            optimistic: ${meta.optimistic},
            retry: ${meta.retry},
            refetch: ${meta.refetch},
            idempotent: ${meta.idempotent},
            idempotencyKeyArg: ${_nullableString(meta.idempotencyKeyArg)},
            closeDialog: ${meta.closeDialog},
          )''';
}

String _invalidateCode(InvalidateMeta meta) {
  return '''
              InvalidateInfo(
                endpoint: ${_nullableString(meta.endpoint)},
                provider: ${_nullableString(meta.provider)},
                argFrom: ${_nullableString(meta.argFrom)},
                family: ${meta.family},
                kind: InvalidateKind.${meta.kind},
              ),''';
}

String _validateStringCode(ValidateStringMeta meta) {
  return '''
            ValidateStringInfo(
              arg: ${_string(meta.arg)},
              notEmpty: ${meta.notEmpty},
              minLength: ${_nullableInt(meta.minLength)},
              maxLength: ${_nullableInt(meta.maxLength)},
              pattern: ${_nullableString(meta.pattern)},
            ),''';
}

String _validateNumberCode(ValidateNumberMeta meta) {
  return '''
            ValidateNumberInfo(
              arg: ${_string(meta.arg)},
              min: ${_nullableNum(meta.min)},
              max: ${_nullableNum(meta.max)},
            ),''';
}

String _validateListCode(ValidateListMeta meta) {
  return '''
            ValidateListInfo(
              arg: ${_string(meta.arg)},
              notEmpty: ${meta.notEmpty},
              minLength: ${_nullableInt(meta.minLength)},
              maxLength: ${_nullableInt(meta.maxLength)},
            ),''';
}

String _string(String value) => jsonEncode(value);

String _nullableString(String? value) =>
    value == null ? 'null' : _string(value);

String _nullableInt(int? value) => value?.toString() ?? 'null';

String _nullableNum(num? value) => value?.toString() ?? 'null';
