import '../generated/protocol.dart';

/// In-memory demo store (no database).
class SelectorRepository {
  SelectorRepository._();

  static final SelectorRepository instance = SelectorRepository._();

  final Map<String, ParentSummary> _parents = {};
  final Map<String, List<ChildRow>> _childrenByParent = {};
  final Map<String, List<String>> _selectionByParent = {};

  void seed() {
    if (_parents.isNotEmpty) return;

    const p1 = 'dept-electronics';
    const p2 = 'dept-grocery';

    _parents[p1] = ParentSummary(id: p1, title: 'Electronics');
    _parents[p2] = ParentSummary(id: p2, title: 'Grocery');

    _childrenByParent[p1] = [
      ChildRow(id: 'c-laptop', parentId: p1, title: 'Laptop'),
      ChildRow(id: 'c-phone', parentId: p1, title: 'Phone'),
      ChildRow(id: 'c-tablet', parentId: p1, title: 'Tablet'),
    ];
    _childrenByParent[p2] = [
      ChildRow(id: 'c-apple', parentId: p2, title: 'Apple'),
      ChildRow(id: 'c-bread', parentId: p2, title: 'Bread'),
    ];

    for (final id in _parents.keys) {
      _selectionByParent[id] = [];
    }
  }

  List<ParentSummary> listParents() =>
      _parents.values.toList()..sort((a, b) => a.title.compareTo(b.title));

  List<ChildRow> listChildren(String parentId) {
    final list = _childrenByParent[parentId] ?? const <ChildRow>[];
    return List<ChildRow>.from(list)
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  SelectionSnapshot getSelection(String parentId) {
    final ids = _selectionByParent[parentId] ?? const <String>[];
    return SelectionSnapshot(parentId: parentId, selectedChildIds: List<String>.from(ids));
  }

  void saveSelection(String parentId, List<String> selectedChildIds) {
    if (!_parents.containsKey(parentId)) {
      throw Exception('Unknown parent: $parentId');
    }
    final valid = _childrenByParent[parentId] ?? const <ChildRow>[];
    final validIds = valid.map((e) => e.id).toSet();
    for (final id in selectedChildIds) {
      if (!validIds.contains(id)) {
        throw Exception('Invalid child id for parent: $id');
      }
    }
    _selectionByParent[parentId] = List<String>.from(selectedChildIds);
  }
}
