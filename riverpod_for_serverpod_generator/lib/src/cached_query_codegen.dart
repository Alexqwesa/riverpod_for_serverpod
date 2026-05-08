import 'package:riverpod_for_serverpod_generator/src/types.dart';

/// Parsed return shape for methods that use [@CachedQuery] entity cache emission.
class CachedQueryReturnShape {
  /// Element type without trailing `?` (e.g. `User`, `UserSummary`).
  final String elementType;

  /// True when the method returns `List<...>`.
  final bool isList;

  /// True when the method returns `T?` (single value, nullable).
  final bool valueNullable;

  const CachedQueryReturnShape({
    required this.elementType,
    required this.isList,
    required this.valueNullable,
  });
}

/// When null, the method should not use `GeneratedEntityCache` (e.g. `void`).
CachedQueryReturnShape? parseCachedQueryReturnType(String unwrappedReturnType) {
  final s = unwrappedReturnType.trim();
  if (s == 'void') return null;

  if (s.startsWith('List<') && s.endsWith('>')) {
    final inner = s.substring(5, s.length - 1).trim();
    return CachedQueryReturnShape(
      elementType: inner,
      isList: true,
      valueNullable: false,
    );
  }

  if (s.endsWith('?')) {
    return CachedQueryReturnShape(
      elementType: s.substring(0, s.length - 1).trim(),
      isList: false,
      valueNullable: true,
    );
  }

  return CachedQueryReturnShape(
    elementType: s,
    isList: false,
    valueNullable: false,
  );
}

/// When true, emit an [AsyncNotifier] with stale-while-revalidate (cached hit +
/// background refresh) instead of a [FutureProvider].
bool useCachedQueryAsyncNotifierSwr(
  MyMethodMeta m,
  String unwrappedReturnType,
) {
  final cq = m.cachedQuery;
  if (cq == null || !cq.backgroundRefresh) return false;
  return parseCachedQueryReturnType(unwrappedReturnType) != null;
}

String cachedQueryStorageProviderName(CachedQueryMeta cq) => cq.secure
    ? 'generatedSecureCacheStorageProvider'
    : 'generatedCacheStorageProvider';

String jsonEncodeArgExpression(MyParamMeta p) {
  final normalized = p.type.replaceAll(' ', '');
  if (normalized == 'DateTime' || normalized == 'DateTime?') {
    return p.isNullable
        ? '${p.name}?.toIso8601String()'
        : '${p.name}.toIso8601String()';
  }
  return p.name;
}

/// Builds `jsonEncode` argument list in method parameter order (positional, then named).
String cachedQueryIndexKeyExpression(MyMethodMeta m) {
  final prefix = '${m.innerProviderName}.${m.name}';
  if (!m.hasPositionalParams && !m.hasNamedParams) {
    return "r'$prefix'";
  }
  final parts = <String>[
    for (final p in m.positionalParams) jsonEncodeArgExpression(p),
    for (final p in m.namedParams) jsonEncodeArgExpression(p),
  ];
  return "r'$prefix' + ':' + jsonEncode([${parts.join(', ')}])";
}

String buildEntityCacheOpen({
  required MyMethodMeta m,
  required CachedQueryReturnShape shape,
  required String storageAsyncPrefix,
}) {
  final cq = m.cachedQuery!;
  final storage = cachedQueryStorageProviderName(cq);
  final indexKeyExpr = cachedQueryIndexKeyExpression(m);
  return '''
    final storage = await $storageAsyncPrefix$storage.future);
    final cache = GeneratedEntityCache<${shape.elementType}>(
      storage: storage,
      entityType: r'${cq.entity}',
      cacheVersion: ${cq.cacheVersion},
      idOf: (e) => e.${cq.idField},
      toJson: (e) => Map<String, Object?>.from(e.toJson()),
      fromJson: ${shape.elementType}.fromJson,
      maxItems: ${cq.maxItems},
    );
    final indexKey = $indexKeyExpr;
''';
}

String buildCachedQueryBlock({
  required MyMethodMeta m,
  required CachedQueryReturnShape shape,
  required String clientCallAwaitResult,
  required String cacheForLine,
}) {
  final ttlExpr = m.cachedQuery!.ttl;

  final readHit = shape.isList
      ? '''
    final cachedList = await cache.readList(indexKey);
    if (cachedList != null) {
      $cacheForLine
      return cachedList;
    }
'''
      : '''
    final cachedList = await cache.readList(indexKey);
    if (cachedList != null && cachedList.isNotEmpty) {
      $cacheForLine
      return cachedList.first;
    }
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

  final open = buildEntityCacheOpen(
    m: m,
    shape: shape,
    storageAsyncPrefix: 'ref.watch(',
  );

  return '''
$open$readHit
    $clientCallAwaitResult
    $putBlock
''';
}
