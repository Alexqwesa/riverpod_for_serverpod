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
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dart:async' as _i2;
import 'package:selector_demo_client/src/protocol/selector/parent_summary.dart'
    as _i3;
import 'package:selector_demo_client/src/protocol/selector/child_row.dart'
    as _i4;
import 'package:selector_demo_client/src/protocol/selector/selection_snapshot.dart'
    as _i5;
import 'protocol.dart' as _i6;

/// {@category Endpoint}
class EndpointSelector extends _i1.EndpointRef {
  EndpointSelector(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'selector';

  _i2.Future<List<_i3.ParentSummary>> listParents() =>
      caller.callServerEndpoint<List<_i3.ParentSummary>>(
        'selector',
        'listParents',
        {},
      );

  _i2.Future<List<_i4.ChildRow>> listChildren(String parentId) =>
      caller.callServerEndpoint<List<_i4.ChildRow>>(
        'selector',
        'listChildren',
        {'parentId': parentId},
      );

  _i2.Future<_i5.SelectionSnapshot> getSelection(String parentId) =>
      caller.callServerEndpoint<_i5.SelectionSnapshot>(
        'selector',
        'getSelection',
        {'parentId': parentId},
      );

  _i2.Future<void> saveSelection(
    String parentId,
    List<String> selectedChildIds,
  ) => caller.callServerEndpoint<void>(
    'selector',
    'saveSelection',
    {
      'parentId': parentId,
      'selectedChildIds': selectedChildIds,
    },
  );
}

class Client extends _i1.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    @Deprecated(
      'Use authKeyProvider instead. This will be removed in future releases.',
    )
    super.authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _i1.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_i1.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
  }) : super(
         host,
         _i6.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    selector = EndpointSelector(this);
  }

  late final EndpointSelector selector;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {'selector': selector};

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {};
}
