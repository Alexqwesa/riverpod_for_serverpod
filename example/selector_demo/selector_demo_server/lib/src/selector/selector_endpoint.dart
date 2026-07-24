import '../generated/protocol.dart';
import 'selector_repository.dart';
import 'package:riverpod_for_serverpod_annotation/riverpod_for_serverpod_annotation.dart';
import 'package:serverpod/serverpod.dart';

class SelectorEndpoint extends Endpoint {
  @CachedQuery(entity: ParentSummary)
  Future<List<ParentSummary>> listParents(Session session) async {
    final r = SelectorRepository.instance..seed();
    return r.listParents();
  }

  @CachedQuery(entity: ChildRow)
  Future<List<ChildRow>> listChildren(Session session, String parentId) async {
    final r = SelectorRepository.instance..seed();
    return r.listChildren(parentId);
  }

  @CachedQuery(
    entity: SelectionSnapshot,
    idField: 'parentId',
  )
  Future<SelectionSnapshot> getSelection(
    Session session,
    String parentId,
  ) async {
    final r = SelectorRepository.instance..seed();
    return r.getSelection(parentId);
  }

  @MutationCommand(
    affects: SelectionSnapshot,
    idArg: 'parentId',
    idempotent: true,
    refetch: RefetchPolicy.none,
    invalidate: [
      Invalidate.providerFamily(
        SelectorEndpoint,
        'listChildren',
        argFrom: 'parentId',
      ),
      Invalidate.providerFamily(
        SelectorEndpoint,
        'getSelection',
        argFrom: 'parentId',
      ),
    ],
  )
  Future<void> saveSelection(
    Session session,
    String parentId,
    List<String> selectedChildIds,
  ) async {
    final r = SelectorRepository.instance..seed();
    r.saveSelection(parentId, selectedChildIds);
  }
}
