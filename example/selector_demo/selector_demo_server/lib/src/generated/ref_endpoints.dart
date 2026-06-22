// GENERATED - DO NOT MODIFY
// @dart=3.0

import 'dart:async';
import 'dart:convert';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod/misc.dart';
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:selector_demo_client/src/protocol/protocol.dart';
import 'package:serverpod_auth_client/serverpod_auth_client.dart';

const generatedEndpointManifest = EndpointManifest(
  endpoints: [
    EndpointInfo(
      name: "SelectorEndpoint",
      methods: [
        MethodInfo(
          name: "listParents",
          returnType: "Future<List<ParentSummary>>",
          positionalParams: [],
          namedParams: [],
          cachedQuery: CachedQueryInfo(
            entity: "ParentSummary",
            idField: "id",
            maxItems: 1000,
            ttl: Duration(minutes: 3),
            secure: false,
            byIdMethod: null,
            mergePolicy: CacheMergePolicy.replaceEntity,
            cacheVersion: 1,
            backgroundRefresh: true,
          ),
          mutationCommand: null,
          validateStrings: [],
          validateNumbers: [],
          validateLists: [],
        ),
        MethodInfo(
          name: "listChildren",
          returnType: "Future<List<ChildRow>>",
          positionalParams: [
            ParamInfo(
              name: "parentId",
              type: "String",
              defaultValue: null,
            ),
          ],
          namedParams: [],
          cachedQuery: CachedQueryInfo(
            entity: "ChildRow",
            idField: "id",
            maxItems: 1000,
            ttl: Duration(minutes: 3),
            secure: false,
            byIdMethod: null,
            mergePolicy: CacheMergePolicy.replaceEntity,
            cacheVersion: 1,
            backgroundRefresh: true,
          ),
          mutationCommand: null,
          validateStrings: [],
          validateNumbers: [],
          validateLists: [],
        ),
        MethodInfo(
          name: "getSelection",
          returnType: "Future<SelectionSnapshot>",
          positionalParams: [
            ParamInfo(
              name: "parentId",
              type: "String",
              defaultValue: null,
            ),
          ],
          namedParams: [],
          cachedQuery: CachedQueryInfo(
            entity: "SelectionSnapshot",
            idField: "parentId",
            maxItems: 1000,
            ttl: Duration(minutes: 3),
            secure: false,
            byIdMethod: null,
            mergePolicy: CacheMergePolicy.replaceEntity,
            cacheVersion: 1,
            backgroundRefresh: true,
          ),
          mutationCommand: null,
          validateStrings: [],
          validateNumbers: [],
          validateLists: [],
        ),
        MethodInfo(
          name: "saveSelection",
          returnType: "Future<void>",
          positionalParams: [
            ParamInfo(
              name: "parentId",
              type: "String",
              defaultValue: null,
            ),
            ParamInfo(
              name: "selectedChildIds",
              type: "List<String>",
              defaultValue: null,
            ),
          ],
          namedParams: [],
          cachedQuery: null,
          mutationCommand: MutationCommandInfo(
            affects: "SelectionSnapshot",
            idArg: "parentId",
            idField: "id",
            byIdMethod: null,
            invalidate: [
              InvalidateInfo(
                provider: "listChildren",
                argFrom: "parentId",
                family: true,
              ),
              InvalidateInfo(
                provider: "getSelection",
                argFrom: "parentId",
                family: true,
              ),
            ],
            optimistic: OptimisticPolicy.none,
            retry: RetryPolicy.connectionOnly,
            refetch: RefetchPolicy.none,
            idempotent: true,
            idempotencyKeyArg: null,
            closeDialog: DialogPolicy.onSuccessOnly,
          ),
          validateStrings: [],
          validateNumbers: [],
          validateLists: [],
        ),
      ],
    ),
  ],
);
typedef Reader = T Function<T>(ProviderListenable<T> provider);
typedef ProviderInvalidator = void Function(ProviderOrFamily provider);

final clientProvider = Provider<Client>((ref) {
  const serverUrlFromEnv = String.fromEnvironment('SERVER_URL');
  final serverUrl =
      serverUrlFromEnv.isEmpty ? 'http://localhost:8080/' : serverUrlFromEnv;
  return Client(serverUrl);
});

class Counter extends Notifier<int> {
  @override
  int build() => 0;

  void updateAll() => state++;
}

final refUpdateAllGeneratedProviders = NotifierProvider<Counter, int>(
  Counter.new,
);

Duration? _noProviderRetry(int retryCount, Object error) => null;

extension RefCacheForExtension on Ref {
  void cacheFor(Duration duration) {
    if (!mounted) return;
    final link = keepAlive();
    final timer = Timer(duration, link.close);

    onDispose(timer.cancel);
  }
}

final class _RefSelectorEndpoint_ListParentsCachedReadNotifier
    extends AsyncNotifier<List<ParentSummary>> {
  Future<List<ParentSummary>> _fetchAndUpdate() async {
    final storage = await ref.read(generatedCacheStorageProvider.future);
    final cache = GeneratedEntityCache<ParentSummary>(
      storage: storage,
      entityType: r'ParentSummary',
      cacheVersion: 1,
      idOf: (e) => e.id,
      toJson: (e) => Map<String, Object?>.from(e.toJson()),
      fromJson: ParentSummary.fromJson,
      maxItems: 1000,
    );
    final indexKey = r'RefSelectorEndpoint.listParents';

    final result = await ref.watch(clientProvider).selector.listParents();
    await cache.putList(indexKey, result, ttl: Duration(minutes: 3));
    ref.cacheFor(const Duration(minutes: 3));
    ref.read(refreshWarningProvider.notifier).clearRefreshFailures();
    return result;
  }

  Future<void> _refreshInBackground() async {
    try {
      final fresh = await _fetchAndUpdate();
      if (ref.mounted) {
        state = AsyncData(fresh);
      }
    } catch (e, st) {
      ref.read(refreshWarningProvider.notifier).recordFailure(
            sourceKey: r'RefSelectorEndpoint.listParents',
            error: e,
          );
    }
  }

  @override
  Future<List<ParentSummary>> build() async {
    ref
      ..watch(refUpdateAllGeneratedProviders)
      ..watch(RefSelectorEndpoint.refUpdateAll);

    final storage = await ref.watch(generatedCacheStorageProvider.future);
    final cache = GeneratedEntityCache<ParentSummary>(
      storage: storage,
      entityType: r'ParentSummary',
      cacheVersion: 1,
      idOf: (e) => e.id,
      toJson: (e) => Map<String, Object?>.from(e.toJson()),
      fromJson: ParentSummary.fromJson,
      maxItems: 1000,
    );
    final indexKey = r'RefSelectorEndpoint.listParents';

    final cachedList = await cache.readList(indexKey);
    if (cachedList != null) {
      ref.cacheFor(const Duration(minutes: 3));
      Future.microtask(() => _refreshInBackground());
      return cachedList;
    }
    try {
      return await _fetchAndUpdate();
    } catch (e, st) {
      ref.read(refreshWarningProvider.notifier).recordFailure(
            sourceKey: r'RefSelectorEndpoint.listParents',
            error: e,
          );
      rethrow;
    }
  }
}

final class _RefSelectorEndpoint_ListChildrenCachedReadNotifier
    extends AsyncNotifier<List<ChildRow>> {
  final String parentId;

  _RefSelectorEndpoint_ListChildrenCachedReadNotifier(this.parentId);

  Future<List<ChildRow>> _fetchAndUpdate() async {
    final storage = await ref.read(generatedCacheStorageProvider.future);
    final cache = GeneratedEntityCache<ChildRow>(
      storage: storage,
      entityType: r'ChildRow',
      cacheVersion: 1,
      idOf: (e) => e.id,
      toJson: (e) => Map<String, Object?>.from(e.toJson()),
      fromJson: ChildRow.fromJson,
      maxItems: 1000,
    );
    final indexKey =
        r'RefSelectorEndpoint.listChildren' + ':' + jsonEncode([parentId]);

    final result =
        await ref.watch(clientProvider).selector.listChildren(parentId);
    await cache.putList(indexKey, result, ttl: Duration(minutes: 3));
    ref.cacheFor(const Duration(minutes: 3));
    ref.read(refreshWarningProvider.notifier).clearRefreshFailures();
    return result;
  }

  Future<void> _refreshInBackground() async {
    try {
      final fresh = await _fetchAndUpdate();
      if (ref.mounted) {
        state = AsyncData(fresh);
      }
    } catch (e, st) {
      ref.read(refreshWarningProvider.notifier).recordFailure(
            sourceKey: r'RefSelectorEndpoint.listChildren',
            error: e,
          );
    }
  }

  @override
  Future<List<ChildRow>> build() async {
    ref
      ..watch(refUpdateAllGeneratedProviders)
      ..watch(RefSelectorEndpoint.refUpdateAll);

    final storage = await ref.watch(generatedCacheStorageProvider.future);
    final cache = GeneratedEntityCache<ChildRow>(
      storage: storage,
      entityType: r'ChildRow',
      cacheVersion: 1,
      idOf: (e) => e.id,
      toJson: (e) => Map<String, Object?>.from(e.toJson()),
      fromJson: ChildRow.fromJson,
      maxItems: 1000,
    );
    final indexKey =
        r'RefSelectorEndpoint.listChildren' + ':' + jsonEncode([parentId]);

    final cachedList = await cache.readList(indexKey);
    if (cachedList != null) {
      ref.cacheFor(const Duration(minutes: 3));
      Future.microtask(() => _refreshInBackground());
      return cachedList;
    }
    try {
      return await _fetchAndUpdate();
    } catch (e, st) {
      ref.read(refreshWarningProvider.notifier).recordFailure(
            sourceKey: r'RefSelectorEndpoint.listChildren',
            error: e,
          );
      rethrow;
    }
  }
}

final class _RefSelectorEndpoint_GetSelectionCachedReadNotifier
    extends AsyncNotifier<SelectionSnapshot> {
  final String parentId;

  _RefSelectorEndpoint_GetSelectionCachedReadNotifier(this.parentId);

  Future<SelectionSnapshot> _fetchAndUpdate() async {
    final storage = await ref.read(generatedCacheStorageProvider.future);
    final cache = GeneratedEntityCache<SelectionSnapshot>(
      storage: storage,
      entityType: r'SelectionSnapshot',
      cacheVersion: 1,
      idOf: (e) => e.parentId,
      toJson: (e) => Map<String, Object?>.from(e.toJson()),
      fromJson: SelectionSnapshot.fromJson,
      maxItems: 1000,
    );
    final indexKey =
        r'RefSelectorEndpoint.getSelection' + ':' + jsonEncode([parentId]);

    final result =
        await ref.watch(clientProvider).selector.getSelection(parentId);
    await cache.putList(indexKey, [result], ttl: Duration(minutes: 3));
    ref.cacheFor(const Duration(minutes: 3));
    ref.read(refreshWarningProvider.notifier).clearRefreshFailures();
    return result;
  }

  Future<void> _refreshInBackground() async {
    try {
      final fresh = await _fetchAndUpdate();
      if (ref.mounted) {
        state = AsyncData(fresh);
      }
    } catch (e, st) {
      ref.read(refreshWarningProvider.notifier).recordFailure(
            sourceKey: r'RefSelectorEndpoint.getSelection',
            error: e,
          );
    }
  }

  @override
  Future<SelectionSnapshot> build() async {
    ref
      ..watch(refUpdateAllGeneratedProviders)
      ..watch(RefSelectorEndpoint.refUpdateAll);

    final storage = await ref.watch(generatedCacheStorageProvider.future);
    final cache = GeneratedEntityCache<SelectionSnapshot>(
      storage: storage,
      entityType: r'SelectionSnapshot',
      cacheVersion: 1,
      idOf: (e) => e.parentId,
      toJson: (e) => Map<String, Object?>.from(e.toJson()),
      fromJson: SelectionSnapshot.fromJson,
      maxItems: 1000,
    );
    final indexKey =
        r'RefSelectorEndpoint.getSelection' + ':' + jsonEncode([parentId]);

    final cachedList = await cache.readList(indexKey);
    if (cachedList != null && cachedList.isNotEmpty) {
      ref.cacheFor(const Duration(minutes: 3));
      Future.microtask(() => _refreshInBackground());
      return cachedList.first;
    }
    try {
      return await _fetchAndUpdate();
    } catch (e, st) {
      ref.read(refreshWarningProvider.notifier).recordFailure(
            sourceKey: r'RefSelectorEndpoint.getSelection',
            error: e,
          );
      rethrow;
    }
  }
}

abstract class RefSelectorEndpoint {
  const RefSelectorEndpoint();

  static final NotifierProvider<Counter, int> refUpdateAll =
      NotifierProvider<Counter, int>(Counter.new);

  static final listParents = AsyncNotifierProvider.autoDispose<
      _RefSelectorEndpoint_ListParentsCachedReadNotifier, List<ParentSummary>>(
    _RefSelectorEndpoint_ListParentsCachedReadNotifier.new,
    retry: _noProviderRetry,
  );

  static final listChildren = AsyncNotifierProvider.family.autoDispose<
      _RefSelectorEndpoint_ListChildrenCachedReadNotifier,
      List<ChildRow>,
      String>(
    _RefSelectorEndpoint_ListChildrenCachedReadNotifier.new,
    retry: _noProviderRetry,
  );

  static final listChildren0 =
      FutureProvider.autoDispose.family<List<ChildRow>, String>(
    (ref, arg) {
      final parentId = arg;
      return ref.watch(RefSelectorEndpoint.listChildren(parentId).future);
    },
    retry: _noProviderRetry,
  );

  static final getSelection = AsyncNotifierProvider.family.autoDispose<
      _RefSelectorEndpoint_GetSelectionCachedReadNotifier,
      SelectionSnapshot,
      String>(
    _RefSelectorEndpoint_GetSelectionCachedReadNotifier.new,
    retry: _noProviderRetry,
  );

  static final getSelection0 =
      FutureProvider.autoDispose.family<SelectionSnapshot, String>(
    (ref, arg) {
      final parentId = arg;
      return ref.watch(RefSelectorEndpoint.getSelection(parentId).future);
    },
    retry: _noProviderRetry,
  );

  static void updateAll(Reader read) {
    read(refUpdateAll.notifier).updateAll();
  }

  static void listParentsInvalidate(ProviderInvalidator invalidate) {
    invalidate(listParents);
  }

  static void listParentsInvalidateAll(ProviderInvalidator invalidate) {
    invalidate(listParents);
  }

  static void listChildrenInvalidate(
    ProviderInvalidator invalidate,
    String args,
  ) {
    invalidate(listChildren(args));
  }

  static void listChildrenInvalidateAll(ProviderInvalidator invalidate) {
    invalidate(listChildren);
  }

  static String listChildren0ToListChildrenArgs(String args) {
    final parentId = args;
    return parentId;
  }

  static void listChildren0Invalidate(
    ProviderInvalidator invalidate,
    String args,
  ) {
    invalidate(listChildren(listChildren0ToListChildrenArgs(args)));
  }

  static void getSelectionInvalidate(
    ProviderInvalidator invalidate,
    String args,
  ) {
    invalidate(getSelection(args));
  }

  static void getSelectionInvalidateAll(ProviderInvalidator invalidate) {
    invalidate(getSelection);
  }

  static String getSelection0ToGetSelectionArgs(String args) {
    final parentId = args;
    return parentId;
  }

  static void getSelection0Invalidate(
    ProviderInvalidator invalidate,
    String args,
  ) {
    invalidate(getSelection(getSelection0ToGetSelectionArgs(args)));
  }

  static void invalidateAfterListParents(Reader read) {
    RefSelectorEndpoint.updateAll(read);
  }

  static void invalidateAfterListChildren(Reader read) {
    RefSelectorEndpoint.updateAll(read);
  }

  static void invalidateAfterGetSelection(Reader read) {
    RefSelectorEndpoint.updateAll(read);
  }

  static void invalidateAfterSaveSelection(Reader read) {
    RefSelectorEndpoint.updateAll(read);
  }
}

abstract final class RefSelectorEndpointCommands {
  static const DialogPolicy dialogPolicyAfterSaveSelection =
      DialogPolicy.onSuccessOnly;

  static Future<void> saveSelection(
      Reader read, String parentId, List<String> selectedChildIds) async {
    try {
      await read(clientProvider)
          .selector
          .saveSelection(parentId, selectedChildIds);
      RefSelectorEndpoint.invalidateAfterSaveSelection(read);
    } catch (e, st) {
      final __enqueue = mutationFailureShouldEnqueue(
        error: e,
        idempotent: true,
        retryEnabled: true,
      );
      if (__enqueue) {
        final retrySnapshot = read(mutationRetryQueueProvider).schedule(
          id: 'SelectorEndpoint.saveSelection.$parentId',
          idempotent: true,
          label: r'saveSelection',
          persistPayload: MutationRetryPersistedPayload(
            opKey: r'SelectorEndpoint.saveSelection',
            args: {
              r'parentId': parentId,
              r'selectedChildIds': selectedChildIds
            },
          ),
          run: () async {
            await read(clientProvider)
                .selector
                .saveSelection(parentId, selectedChildIds);
            RefSelectorEndpoint.invalidateAfterSaveSelection(read);
          },
        );
        read(refreshWarningProvider.notifier).recordQueuedMutation(
          mutationId: retrySnapshot.id,
          queuedMutationCount: read(mutationRetryQueueProvider).length,
          error: e,
          nextRetryAt: retrySnapshot.nextRetryAt,
        );
      }
      rethrow;
    }
  }
}

final selectorMutationControllerProvider =
    AsyncNotifierProvider<SelectorMutationController, void>(
  SelectorMutationController.new,
);

final class SelectorMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> saveSelection(
      String parentId, List<String> selectedChildIds) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await RefSelectorEndpointCommands.saveSelection(
          ref.read, parentId, selectedChildIds);
    });
  }
}

bool _riverpodForServerpodRegisterMutationReplays() {
  MutationRetryReplayRegistry.register(r'SelectorEndpoint.saveSelection',
      (ref, args) async {
    await RefSelectorEndpointCommands.saveSelection(ref.read,
        args[r'parentId'] as String, args[r'selectedChildIds'] as List<String>);
  });
  return true;
}

final _riverpodForServerpodMutationReplayReady =
    _riverpodForServerpodRegisterMutationReplays();
