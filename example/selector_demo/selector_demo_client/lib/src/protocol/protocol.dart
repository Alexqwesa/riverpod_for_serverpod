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
import 'selector/child_row.dart' as _i2;
import 'selector/parent_summary.dart' as _i3;
import 'selector/selection_snapshot.dart' as _i4;
import 'package:selector_demo_client/src/protocol/selector/parent_summary.dart'
    as _i5;
import 'package:selector_demo_client/src/protocol/selector/child_row.dart'
    as _i6;
export 'selector/child_row.dart';
export 'selector/parent_summary.dart';
export 'selector/selection_snapshot.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i2.ChildRow) {
      return _i2.ChildRow.fromJson(data) as T;
    }
    if (t == _i3.ParentSummary) {
      return _i3.ParentSummary.fromJson(data) as T;
    }
    if (t == _i4.SelectionSnapshot) {
      return _i4.SelectionSnapshot.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.ChildRow?>()) {
      return (data != null ? _i2.ChildRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.ParentSummary?>()) {
      return (data != null ? _i3.ParentSummary.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.SelectionSnapshot?>()) {
      return (data != null ? _i4.SelectionSnapshot.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i5.ParentSummary>) {
      return (data as List)
              .map((e) => deserialize<_i5.ParentSummary>(e))
              .toList()
          as T;
    }
    if (t == List<_i6.ChildRow>) {
      return (data as List).map((e) => deserialize<_i6.ChildRow>(e)).toList()
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.ChildRow => 'ChildRow',
      _i3.ParentSummary => 'ParentSummary',
      _i4.SelectionSnapshot => 'SelectionSnapshot',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'selector_demo.',
        '',
      );
    }

    switch (data) {
      case _i2.ChildRow():
        return 'ChildRow';
      case _i3.ParentSummary():
        return 'ParentSummary';
      case _i4.SelectionSnapshot():
        return 'SelectionSnapshot';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'ChildRow') {
      return deserialize<_i2.ChildRow>(data['data']);
    }
    if (dataClassName == 'ParentSummary') {
      return deserialize<_i3.ParentSummary>(data['data']);
    }
    if (dataClassName == 'SelectionSnapshot') {
      return deserialize<_i4.SelectionSnapshot>(data['data']);
    }
    return super.deserializeByClassName(data);
  }

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
