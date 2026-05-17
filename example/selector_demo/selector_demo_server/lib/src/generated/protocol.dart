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
import 'package:serverpod/protocol.dart' as _i2;
import 'selector/child_row.dart' as _i3;
import 'selector/parent_summary.dart' as _i4;
import 'selector/selection_snapshot.dart' as _i5;
import 'package:selector_demo_server/src/generated/selector/parent_summary.dart'
    as _i6;
import 'package:selector_demo_server/src/generated/selector/child_row.dart'
    as _i7;
export 'selector/child_row.dart';
export 'selector/parent_summary.dart';
export 'selector/selection_snapshot.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    ..._i2.Protocol.targetTableDefinitions,
  ];

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

    if (t == _i3.ChildRow) {
      return _i3.ChildRow.fromJson(data) as T;
    }
    if (t == _i4.ParentSummary) {
      return _i4.ParentSummary.fromJson(data) as T;
    }
    if (t == _i5.SelectionSnapshot) {
      return _i5.SelectionSnapshot.fromJson(data) as T;
    }
    if (t == _i1.getType<_i3.ChildRow?>()) {
      return (data != null ? _i3.ChildRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.ParentSummary?>()) {
      return (data != null ? _i4.ParentSummary.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.SelectionSnapshot?>()) {
      return (data != null ? _i5.SelectionSnapshot.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i6.ParentSummary>) {
      return (data as List)
              .map((e) => deserialize<_i6.ParentSummary>(e))
              .toList()
          as T;
    }
    if (t == List<_i7.ChildRow>) {
      return (data as List).map((e) => deserialize<_i7.ChildRow>(e)).toList()
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i3.ChildRow => 'ChildRow',
      _i4.ParentSummary => 'ParentSummary',
      _i5.SelectionSnapshot => 'SelectionSnapshot',
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
      case _i3.ChildRow():
        return 'ChildRow';
      case _i4.ParentSummary():
        return 'ParentSummary';
      case _i5.SelectionSnapshot():
        return 'SelectionSnapshot';
    }
    className = _i2.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod.$className';
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
      return deserialize<_i3.ChildRow>(data['data']);
    }
    if (dataClassName == 'ParentSummary') {
      return deserialize<_i4.ParentSummary>(data['data']);
    }
    if (dataClassName == 'SelectionSnapshot') {
      return deserialize<_i5.SelectionSnapshot>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _i2.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'selector_demo';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _i2.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
