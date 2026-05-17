import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:generic_search_selector/generic_search_selector.dart';
import 'package:selector_demo_client/selector_demo_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

late final Client client;

/// Starts the Flutter app (connectivity-aware Serverpod client + [ProviderScope]).
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final serverUrl = await getServerUrl();
  client = Client(serverUrl)..connectivityMonitor = FlutterConnectivityMonitor();

  runApp(
    ProviderScope(
      overrides: [clientProvider.overrideWithValue(client)],
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
                initialSelectedIds: _parentId != null ? <String>[_parentId!] : <String>[],
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
              error: (err, _) =>
                  Text('Failed to load departments: $err', key: const Key('parents_error')),
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
                  initialSelectedIds: List<String>.from(selection.selectedChildIds),
                  triggerChild: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Choose items (multi-select), then close to save'),
                  ),
                  onFinish: (finalIds, {required added, required removed}) async {
                    await _persist(finalIds);
                  },
                ),
                const SizedBox(height: 16),
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
      await RefSelectorEndpointCommands.saveSelection(
        ref.read,
        widget.parentId,
        ids,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Selection saved on server')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
}
