import 'package:recase/recase.dart';
import 'package:riverpod_for_serverpod_generator/src/cached_query_codegen.dart';
import 'package:riverpod_for_serverpod_generator/src/types.dart';

String cachedReadNotifierClassName(MyMethodMeta m) =>
    '_${m.innerProviderName}_${ReCase(m.name).pascalCase}CachedReadNotifier';

/// Emits a `final class ... extends AsyncNotifier<...>` for [@CachedQuery] SWR.
String? buildCachedQueryNotifierSource({
  required MyMethodMeta m,
  required String clientField,
  required String returnType,
  required SwrNotifierHostParams host,
  required String refWatchBlock,
}) {
  if (!useCachedQueryAsyncNotifierSwr(m, returnType)) return null;
  final shape = parseCachedQueryReturnType(returnType)!;
  final className = cachedReadNotifierClassName(m);
  final cq = m.cachedQuery!;
  final ttlExpr = cq.ttl;
  final timeout = m.timeout != null ? '.timeout(const ${m.timeout})' : '';
  final rpc =
      'ref.watch(clientProvider).$clientField.${m.name}(${host.rpcArgs})$timeout';
  final cacheFor = 'ref.cacheFor(const ${m.cacheTtl});';
  final srcKey = '${m.innerProviderName}.${m.name}';

  final ctor = host.instanceFields.isEmpty
      ? ''
      : '''
  ${host.instanceFields}

  $className(${host.constructorParams});
''';

  final putBlock = shape.isList
      ? 'await cache.putList(indexKey, result, ttl: $ttlExpr);'
      : shape.valueNullable
          ? '''
    if (result != null) {
      await cache.putList(indexKey, [result], ttl: $ttlExpr);
    }
'''
          : 'await cache.putList(indexKey, [result], ttl: $ttlExpr);';

  final cacheOpenWatch = buildEntityCacheOpen(
    m: m,
    shape: shape,
    storageAsyncPrefix: 'ref.watch(',
  );
  final cacheOpenRead = buildEntityCacheOpen(
    m: m,
    shape: shape,
    storageAsyncPrefix: 'ref.read(',
  );

  final cachedReturn = shape.isList ? 'cachedList' : 'cachedList.first';

  final cachedHitCond =
      shape.isList ? 'cachedList != null' : 'cachedList != null && cachedList.isNotEmpty';

  final prelude = host.buildParamPrelude.isEmpty
      ? ''
      : '    ${host.buildParamPrelude.trimRight()}\n';

  return '''
final class $className extends AsyncNotifier<$returnType> {
$ctor
  Future<$returnType> _fetchAndUpdate() async {
$cacheOpenRead
    final result = await $rpc;
    $putBlock
    $cacheFor
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
            sourceKey: r'$srcKey',
            error: e,
          );
    }
  }

  @override
  Future<$returnType> build() async {
    $refWatchBlock
$prelude$cacheOpenWatch
    final cachedList = await cache.readList(indexKey);
    if ($cachedHitCond) {
      $cacheFor
      Future.microtask(() => _refreshInBackground());
      return $cachedReturn;
    }
    try {
      return await _fetchAndUpdate();
    } catch (e, st) {
      ref.read(refreshWarningProvider.notifier).recordFailure(
            sourceKey: r'$srcKey',
            error: e,
          );
      rethrow;
    }
  }
}
''';
}
