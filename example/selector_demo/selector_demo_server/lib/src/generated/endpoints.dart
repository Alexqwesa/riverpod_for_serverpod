/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import '../selector/selector_endpoint.dart' as _i2;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'selector': _i2.SelectorEndpoint()
        ..initialize(
          server,
          'selector',
          null,
        ),
    };
    connectors['selector'] = _i1.EndpointConnector(
      name: 'selector',
      endpoint: endpoints['selector']!,
      methodConnectors: {
        'listParents': _i1.MethodConnector(
          name: 'listParents',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['selector'] as _i2.SelectorEndpoint)
                  .listParents(session),
        ),
        'listChildren': _i1.MethodConnector(
          name: 'listChildren',
          params: {
            'parentId': _i1.ParameterDescription(
              name: 'parentId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['selector'] as _i2.SelectorEndpoint).listChildren(
                    session,
                    params['parentId'],
                  ),
        ),
        'getSelection': _i1.MethodConnector(
          name: 'getSelection',
          params: {
            'parentId': _i1.ParameterDescription(
              name: 'parentId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['selector'] as _i2.SelectorEndpoint).getSelection(
                    session,
                    params['parentId'],
                  ),
        ),
        'saveSelection': _i1.MethodConnector(
          name: 'saveSelection',
          params: {
            'parentId': _i1.ParameterDescription(
              name: 'parentId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'selectedChildIds': _i1.ParameterDescription(
              name: 'selectedChildIds',
              type: _i1.getType<List<String>>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['selector'] as _i2.SelectorEndpoint).saveSelection(
                    session,
                    params['parentId'],
                    params['selectedChildIds'],
                  ),
        ),
      },
    );
  }
}
