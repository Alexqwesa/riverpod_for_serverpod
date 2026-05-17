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
import 'package:selector_demo_client/src/protocol/protocol.dart' as _i2;

abstract class SelectionSnapshot implements _i1.SerializableModel {
  SelectionSnapshot._({
    required this.parentId,
    required this.selectedChildIds,
  });

  factory SelectionSnapshot({
    required String parentId,
    required List<String> selectedChildIds,
  }) = _SelectionSnapshotImpl;

  factory SelectionSnapshot.fromJson(Map<String, dynamic> jsonSerialization) {
    return SelectionSnapshot(
      parentId: jsonSerialization['parentId'] as String,
      selectedChildIds: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['selectedChildIds'],
      ),
    );
  }

  String parentId;

  List<String> selectedChildIds;

  /// Returns a shallow copy of this [SelectionSnapshot]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  SelectionSnapshot copyWith({
    String? parentId,
    List<String>? selectedChildIds,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SelectionSnapshot',
      'parentId': parentId,
      'selectedChildIds': selectedChildIds.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _SelectionSnapshotImpl extends SelectionSnapshot {
  _SelectionSnapshotImpl({
    required String parentId,
    required List<String> selectedChildIds,
  }) : super._(
         parentId: parentId,
         selectedChildIds: selectedChildIds,
       );

  /// Returns a shallow copy of this [SelectionSnapshot]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  SelectionSnapshot copyWith({
    String? parentId,
    List<String>? selectedChildIds,
  }) {
    return SelectionSnapshot(
      parentId: parentId ?? this.parentId,
      selectedChildIds:
          selectedChildIds ?? this.selectedChildIds.map((e0) => e0).toList(),
    );
  }
}
