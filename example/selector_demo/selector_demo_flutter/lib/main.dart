import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:generic_search_selector/generic_search_selector.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_for_serverpod_hive_storage/riverpod_for_serverpod_hive_storage.dart';
import 'package:riverpod_for_serverpod_runtime/riverpod_for_serverpod_runtime.dart';
import 'package:selector_demo_client/selector_demo_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

late final Client client;

/// Starts the Flutter app (connectivity-aware Serverpod client + [ProviderScope]).
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final cacheStorage = await openHiveGeneratedCacheStorage(
    boxName: 'selector_demo_cache',
  );
  final retryKv = await openHiveGeneratedKeyValueStorage(
    boxName: 'selector_demo_mutation_retry',
  );

  final serverUrl = await getServerUrl();
  client = Client(serverUrl)..connectivityMonitor = FlutterConnectivityMonitor();

  runApp(
    ProviderScope(
      overrides: [
        clientProvider.overrideWithValue(client),
        generatedCacheStorageProvider.overrideWith((ref) async => cacheStorage),
        mutationRetryPersistenceStorageProvider.overrideWithValue(retryKv),
      ],
      child: const SelectorDemoApp(),
    ),
  );
}

void main() {
  bootstrap();
}

class SelectorDemoApp extends StatelessWidget {
  const SelectorDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Selector demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SelectorHomePage(),
    );
  }
}

class SelectorHomePage extends ConsumerStatefulWidget {
  const SelectorHomePage({super.key});

  @override
  ConsumerState<SelectorHomePage> createState() => _SelectorHomePageState();
}

class _SelectorHomePageState extends ConsumerState<SelectorHomePage> {
  String? _parentId;

  @override
  Widget build(BuildContext context) {
    final parentsAsync = ref.watch(RefSelectorEndpoint.listParents);
    final warning = ref.watch(refreshWarningProvider);

    return Scaffold(
      key: const Key('selector_scaffold'),
      appBar: AppBar(
        key: const Key('app_bar'),
        title: const Text('Selector demo', key: Key('app_title')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (warning.hasWarning) SyncWarningBanner(warning: warning),
            Text(
              'Department',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            parentsAsync.when(
              data: (parents) =>
                  GenericSearchAnchorPicker<ParentSummary, String>(
                key: const Key('parent_picker'),
                config: GenericPickerConfig<ParentSummary, String>(
                  title: 'Department',
                  loadItems: (_) async => parents,
                  idOf: (p) => p.id,
                  labelOf: (p) => p.title,
                  searchTermsOf: (p) => [p.title, p.id],
                ),
                mode: PickerMode.radio,
                initialSelectedIds:
                    _parentId != null ? <String>[_parentId!] : <String>[],
                triggerChild: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _parentId == null
                        ? 'Choose a department'
                        : 'Department: ${_labelForParent(parents, _parentId!)}',
                  ),
                ),
                onFinish: (finalIds, {required added, required removed}) async {
                  setState(() {
                    _parentId = finalIds.isEmpty ? null : finalIds.first;
                  });
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text(
                'Failed to load departments: $err',
                key: const Key('parents_error'),
              ),
            ),
            const SizedBox(height: 24),
            if (_parentId != null) ...[
              Text(
                'Items',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _ChildPickers(parentId: _parentId!),
            ],
          ],
        ),
      ),
    );
  }

  String _labelForParent(List<ParentSummary> parents, String id) {
    for (final p in parents) {
      if (p.id == id) return p.title;
    }
    return id;
  }
}

class SyncWarningBanner extends ConsumerWidget {
  const SyncWarningBanner({super.key, required this.warning});

  final RefreshWarningState warning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final parts = <String>[];
    if (warning.failedRefreshCount > 0) {
      parts.add('${warning.failedRefreshCount} refresh failure(s)');
    }
    if (warning.queuedMutationCount > 0) {
      parts.add('${warning.queuedMutationCount} queued mutation(s)');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        key: const Key('sync_warning_banner'),
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parts.isEmpty ? 'Sync warning' : parts.join(' · '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              if (warning.queuedMutationCount > 0)
                TextButton(
                  key: const Key('retry_mutations_button'),
                  onPressed: () async {
                    final n = await ref
                        .read(mutationRetryQueueProvider)
                        .retryAllReady();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Retried $n mutation(s)')),
                    );
                  },
                  child: const Text('Retry now'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildPickers extends ConsumerStatefulWidget {
  const _ChildPickers({required this.parentId});

  final String parentId;

  @override
  ConsumerState<_ChildPickers> createState() => _ChildPickersState();
}

class _ChildPickersState extends ConsumerState<_ChildPickers> {
  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(
      RefSelectorEndpoint.listChildren(widget.parentId),
    );
    final selectionAsync = ref.watch(
      RefSelectorEndpoint.getSelection(widget.parentId),
    );
    final mutationState = ref.watch(selectorMutationControllerProvider);

    return childrenAsync.when(
      data: (children) {
        return selectionAsync.when(
          data: (selection) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GenericSearchAnchorPicker<ChildRow, String>(
                  key: const Key('child_picker'),
                  config: GenericPickerConfig<ChildRow, String>(
                    title: 'Items',
                    loadItems: (_) async => children,
                    idOf: (c) => c.id,
                    labelOf: (c) => c.title,
                    searchTermsOf: (c) => [c.title, c.id],
                  ),
                  mode: PickerMode.multi,
                  initialSelectedIds:
                      List<String>.from(selection.selectedChildIds),
                  triggerChild: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose items (multi-select), then close to save',
                    ),
                  ),
                  onFinish: (finalIds, {required added, required removed}) async {
                    await _persist(finalIds);
                  },
                ),
                const SizedBox(height: 16),
                if (mutationState.isLoading)
                  const LinearProgressIndicator(key: Key('save_progress')),
                Text(
                  'Saved on server: ${selection.selectedChildIds.join(', ')}',
                  key: const Key('saved_summary'),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Failed to load selection: $err'),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Failed to load items: $err'),
    );
  }

  Future<void> _persist(List<String> ids) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(selectorMutationControllerProvider.notifier).saveSelection(
            widget.parentId,
            ids,
          );
      if (!mounted) return;
      final state = ref.read(selectorMutationControllerProvider);
      if (state.hasError) {
        messenger.showSnackBar(
          SnackBar(content: Text('Save failed: ${state.error}')),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Selection saved on server')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
}
