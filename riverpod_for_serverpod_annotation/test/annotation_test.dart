import 'package:riverpod_for_serverpod_annotation/riverpod_for_serverpod_annotation.dart';
import 'package:test/test.dart';

class UserSummary {
  const UserSummary();
}

void main() {
  group('CachedQuery', () {
    test('uses V1 cache defaults', () {
      const annotation = CachedQuery(entity: UserSummary);

      expect(annotation.entity, UserSummary);
      expect(annotation.idField, 'id');
      expect(annotation.maxItems, 1000);
      expect(annotation.ttl, const Duration(minutes: 3));
      expect(annotation.secure, isFalse);
      expect(annotation.byIdMethod, isNull);
      expect(annotation.mergePolicy, CacheMergePolicy.refetchById);
      expect(annotation.cacheVersion, 1);
      expect(annotation.backgroundRefresh, isTrue);
    });

    test('supports explicit cache configuration', () {
      const annotation = CachedQuery(
        entity: UserSummary,
        idField: 'uuid',
        maxItems: 250,
        ttl: Duration(minutes: 10),
        secure: true,
        byIdMethod: 'getUserSummaryById',
        mergePolicy: CacheMergePolicy.mergeReturnedEntity,
        cacheVersion: 2,
        backgroundRefresh: false,
      );

      expect(annotation.idField, 'uuid');
      expect(annotation.maxItems, 250);
      expect(annotation.ttl, const Duration(minutes: 10));
      expect(annotation.secure, isTrue);
      expect(annotation.byIdMethod, 'getUserSummaryById');
      expect(annotation.mergePolicy, CacheMergePolicy.mergeReturnedEntity);
      expect(annotation.cacheVersion, 2);
      expect(annotation.backgroundRefresh, isFalse);
    });
  });

  group('MutationCommand', () {
    test('uses conservative command defaults', () {
      const annotation = MutationCommand(affects: UserSummary);

      expect(annotation.affects, UserSummary);
      expect(annotation.idArg, isNull);
      expect(annotation.idField, 'id');
      expect(annotation.byIdMethod, isNull);
      expect(annotation.invalidate, isEmpty);
      expect(annotation.optimistic, OptimisticPolicy.none);
      expect(annotation.retry, RetryPolicy.connectionOnly);
      expect(annotation.refetch, RefetchPolicy.byId);
      expect(annotation.idempotent, isFalse);
      expect(annotation.idempotencyKeyArg, isNull);
      expect(annotation.closeDialog, DialogPolicy.onSuccessOnly);
    });

    test('supports invalidation, optimistic cache, and retry metadata', () {
      const annotation = MutationCommand(
        affects: UserSummary,
        idArg: 'userId',
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
      );

      expect(annotation.idArg, 'userId');
      expect(annotation.byIdMethod, 'getUserSummaryById');
      expect(annotation.invalidate, hasLength(2));
      expect(annotation.invalidate.first.provider, 'listUsersByRole');
      expect(annotation.invalidate.first.family, isFalse);
      expect(annotation.invalidate.last.provider, 'getUserSummaryById');
      expect(annotation.invalidate.last.argFrom, 'userId');
      expect(annotation.invalidate.last.family, isTrue);
      expect(annotation.optimistic, OptimisticPolicy.patchLocalCache);
      expect(annotation.refetch, RefetchPolicy.mergeReturnedEntity);
      expect(annotation.idempotent, isTrue);
      expect(annotation.idempotencyKeyArg, 'clientRequestId');
    });
  });

  group('validation annotations', () {
    test('stores string validation metadata', () {
      const annotation = ValidateString(
        arg: 'roleName',
        notEmpty: true,
        minLength: 2,
        maxLength: 50,
        pattern: r'^[a-z_]+$',
      );

      expect(annotation.arg, 'roleName');
      expect(annotation.notEmpty, isTrue);
      expect(annotation.minLength, 2);
      expect(annotation.maxLength, 50);
      expect(annotation.pattern, r'^[a-z_]+$');
    });

    test('stores number and list validation metadata', () {
      const number = ValidateNumber(arg: 'count', min: 1, max: 10);
      const list = ValidateList(arg: 'userIds', notEmpty: true, maxLength: 100);

      expect(number.min, 1);
      expect(number.max, 10);
      expect(list.notEmpty, isTrue);
      expect(list.maxLength, 100);
    });
  });
}
