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

abstract class ChildRow implements _i1.SerializableModel {
  ChildRow._({
    required this.id,
    required this.parentId,
    required this.title,
  });

  factory ChildRow({
    required String id,
    required String parentId,
    required String title,
  }) = _ChildRowImpl;

  factory ChildRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChildRow(
      id: jsonSerialization['id'] as String,
      parentId: jsonSerialization['parentId'] as String,
      title: jsonSerialization['title'] as String,
    );
  }

  String id;

  String parentId;

  String title;

  /// Returns a shallow copy of this [ChildRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ChildRow copyWith({
    String? id,
    String? parentId,
    String? title,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChildRow',
      'id': id,
      'parentId': parentId,
      'title': title,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _ChildRowImpl extends ChildRow {
  _ChildRowImpl({
    required String id,
    required String parentId,
    required String title,
  }) : super._(
         id: id,
         parentId: parentId,
         title: title,
       );

  /// Returns a shallow copy of this [ChildRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ChildRow copyWith({
    String? id,
    String? parentId,
    String? title,
  }) {
    return ChildRow(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      title: title ?? this.title,
    );
  }
}
