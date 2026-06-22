import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:riverpod_for_serverpod_generator/src/read_annotations.dart';
import 'package:test/test.dart';

void main() {
  group('extractCacheTtlLiteral', () {
    test('extracts simple duration literal', () {
      const source = '''
@CacheTtl(Duration(minutes: 5))
Future<Data> getData() {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractCacheTtlLiteral(node), 'Duration(minutes: 5)');
    });

    test('extracts duration with const keyword', () {
      const source = '''
@CacheTtl(const Duration(hours: 1))
Future<Data> getData() {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractCacheTtlLiteral(node), 'Duration(hours: 1)');
    });

    test('extracts duration with seconds', () {
      const source = '''
@CacheTtl(Duration(seconds: 30))
Future<Data> getData() {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractCacheTtlLiteral(node), 'Duration(seconds: 30)');
    });

    test('returns null when no CacheTtl annotation', () {
      const source = '''
Future<Data> getData() {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractCacheTtlLiteral(node), isNull);
    });

    test('handles prefixed annotation name', () {
      const source = '''
@CacheTtl(Duration(days: 1))
Future<Data> getData() {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractCacheTtlLiteral(node), 'Duration(days: 1)');
    });
  });

  group('extractTimeoutLiteral', () {
    test('extracts timeout duration literal', () {
      const source = '''
@Timeout(Duration(minutes: 2))
Future<Data> getData() {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractTimeoutLiteral(node), 'Duration(minutes: 2)');
    });
  });

  group('extractCachedQueryMeta', () {
    test('extracts cached query defaults', () {
      const source = '''
@CachedQuery(entity: UserSummary)
Future<List<UserSummary>> listUsers(Session session) async => [];
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      final meta = extractCachedQueryMeta(node);

      expect(meta, isNotNull);
      expect(meta!.entity, 'UserSummary');
      expect(meta.idField, 'id');
      expect(meta.maxItems, 1000);
      expect(meta.ttl, 'Duration(minutes: 3)');
      expect(meta.secure, isFalse);
      expect(meta.byIdMethod, isNull);
      expect(meta.mergePolicy, 'CacheMergePolicy.replaceEntity');
      expect(meta.cacheVersion, 1);
      expect(meta.backgroundRefresh, isTrue);
    });

    test('extracts explicit cached query metadata', () {
      const source = '''
@CachedQuery(
  entity: UserSummary,
  idField: 'uuid',
  maxItems: 250,
  ttl: Duration(minutes: 10),
  secure: true,
  byIdMethod: 'getUserSummaryById',
  mergePolicy: CacheMergePolicy.refetchById,
  cacheVersion: 2,
  backgroundRefresh: false,
)
Future<List<UserSummary>> listUsers(Session session) async => [];
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      final meta = extractCachedQueryMeta(node)!;

      expect(meta.entity, 'UserSummary');
      expect(meta.idField, 'uuid');
      expect(meta.maxItems, 250);
      expect(meta.ttl, 'Duration(minutes: 10)');
      expect(meta.secure, isTrue);
      expect(meta.byIdMethod, 'getUserSummaryById');
      expect(meta.mergePolicy, 'CacheMergePolicy.refetchById');
      expect(meta.cacheVersion, 2);
      expect(meta.backgroundRefresh, isFalse);
    });
  });

  group('extractMutationCommandMeta', () {
    test('extracts mutation defaults', () {
      const source = '''
@MutationCommand(affects: UserSummary)
Future<UserSummary> updateUser(Session session) async => UserSummary();
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      final meta = extractMutationCommandMeta(node);

      expect(meta, isNotNull);
      expect(meta!.affects, 'UserSummary');
      expect(meta.idArg, isNull);
      expect(meta.idField, 'id');
      expect(meta.byIdMethod, isNull);
      expect(meta.invalidate, isEmpty);
      expect(meta.optimistic, 'OptimisticPolicy.none');
      expect(meta.retry, 'RetryPolicy.connectionOnly');
      expect(meta.refetch, 'RefetchPolicy.byId');
      expect(meta.idempotent, isFalse);
      expect(meta.idempotencyKeyArg, isNull);
      expect(meta.closeDialog, 'DialogPolicy.onSuccessOnly');
    });

    test('extracts mutation command metadata and invalidation descriptors', () {
      const source = '''
@MutationCommand(
  affects: UserSummary,
  idArg: 'userId',
  idField: 'uuid',
  byIdMethod: 'getUserSummaryById',
  invalidate: [
    Invalidate.all('listUsersByRole'),
    Invalidate.family('getUserSummaryById', argFrom: 'userId'),
  ],
  optimistic: OptimisticPolicy.patchLocalCache,
  retry: RetryPolicy.connectionOnly,
  refetch: RefetchPolicy.mergeReturnedEntity,
  idempotent: true,
  idempotencyKeyArg: 'clientRequestId',
  closeDialog: DialogPolicy.never,
)
Future<UserSummary> updateUser(Session session) async => UserSummary();
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      final meta = extractMutationCommandMeta(node)!;

      expect(meta.affects, 'UserSummary');
      expect(meta.idArg, 'userId');
      expect(meta.idField, 'uuid');
      expect(meta.byIdMethod, 'getUserSummaryById');
      expect(meta.invalidate, hasLength(2));
      expect(meta.invalidate.first.provider, 'listUsersByRole');
      expect(meta.invalidate.first.family, isFalse);
      expect(meta.invalidate.last.provider, 'getUserSummaryById');
      expect(meta.invalidate.last.argFrom, 'userId');
      expect(meta.invalidate.last.family, isTrue);
      expect(meta.optimistic, 'OptimisticPolicy.patchLocalCache');
      expect(meta.refetch, 'RefetchPolicy.mergeReturnedEntity');
      expect(meta.idempotent, isTrue);
      expect(meta.idempotencyKeyArg, 'clientRequestId');
      expect(meta.closeDialog, 'DialogPolicy.never');
    });

    test('extracts typed invalidation descriptors', () {
      const source = '''
@MutationCommand(
  affects: Event,
  invalidate: [
    Invalidate.self(EventEndpoint),
    Invalidate.endpoint(UserEndpoint),
    Invalidate.provider(EventEndpoint, 'listEvents'),
    Invalidate.providerFamily(EventEndpoint, 'getEventById', argFrom: 'eventId'),
  ],
)
Future<void> updateEvent(Session session, int eventId) async {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      final meta = extractMutationCommandMeta(node)!;

      expect(meta.invalidate, hasLength(4));
      expect(meta.invalidate[0].kind, 'self');
      expect(meta.invalidate[0].endpoint, 'EventEndpoint');
      expect(meta.invalidate[1].kind, 'endpoint');
      expect(meta.invalidate[1].endpoint, 'UserEndpoint');
      expect(meta.invalidate[2].kind, 'provider');
      expect(meta.invalidate[2].endpoint, 'EventEndpoint');
      expect(meta.invalidate[2].provider, 'listEvents');
      expect(meta.invalidate[2].argFrom, isNull);
      expect(meta.invalidate[3].provider, 'getEventById');
      expect(meta.invalidate[3].argFrom, 'eventId');
      expect(meta.invalidate[3].family, isTrue);
    });
  });

  group('validation metadata extractors', () {
    test('extracts string, number, and list validation metadata', () {
      const source = '''
@ValidateString(
  arg: 'roleName',
  notEmpty: true,
  minLength: 2,
  maxLength: 50,
  pattern: r'^[a-z_]+\$',
)
@ValidateNumber(arg: 'age', min: 18, max: 99.5)
@ValidateList(arg: 'userIds', notEmpty: true, maxLength: 100)
Future<void> updateUser(Session session) async {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;

      final stringMeta = extractValidateStringMeta(node).single;
      expect(stringMeta.arg, 'roleName');
      expect(stringMeta.notEmpty, isTrue);
      expect(stringMeta.minLength, 2);
      expect(stringMeta.maxLength, 50);
      expect(stringMeta.pattern, r'^[a-z_]+$');

      final numberMeta = extractValidateNumberMeta(node).single;
      expect(numberMeta.arg, 'age');
      expect(numberMeta.min, 18);
      expect(numberMeta.max, 99.5);

      final listMeta = extractValidateListMeta(node).single;
      expect(listMeta.arg, 'userIds');
      expect(listMeta.notEmpty, isTrue);
      expect(listMeta.maxLength, 100);
    });
  });

  group('extractInvalidateTargets', () {
    test('extracts endpoint targets from RefInvalidate', () {
      const source = '''
@RefInvalidate(['AdminEndpoint', 'UserSummaryEndpoint'])
Future<void> sync() async {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(
        extractInvalidateTargets(node),
        ['AdminEndpoint', 'UserSummaryEndpoint'],
      );
      expect(extractInvalidateIncludesSelf(node), isTrue);
    });

    test('extracts includeSelf flag from RefInvalidate', () {
      const source = '''
@RefInvalidate(['BankBalanceEndpoint'], includeSelf: false)
Future<void> sync() async {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(extractInvalidateTargets(node), ['BankBalanceEndpoint']);
      expect(extractInvalidateIncludesSelf(node), isFalse);
    });
  });

  group('hasDoNotGenerateAnnotation', () {
    test('detects DoNotGenerate annotation', () {
      const source = '''
@DoNotGenerate()
Future<void> internalOnly() async {}
''';
      final parsed = parseString(content: source);
      final node = parsed.unit.declarations.first;
      expect(hasDoNotGenerateAnnotation(node), isTrue);
    });
  });
}
