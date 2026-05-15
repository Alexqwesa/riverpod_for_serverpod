import 'dart:convert';

/// Serializable args for replaying an idempotent mutation after restart.
class MutationRetryPersistedPayload {
  final String opKey;
  final Map<String, Object?> args;

  const MutationRetryPersistedPayload({
    required this.opKey,
    required this.args,
  });

  Map<String, Object?> toJson() => {
        'opKey': opKey,
        'args': args,
      };

  factory MutationRetryPersistedPayload.fromJson(Map<String, Object?> json) {
    return MutationRetryPersistedPayload(
      opKey: json['opKey']! as String,
      args: Map<String, Object?>.from(json['args']! as Map),
    );
  }
}

/// JSON-friendly snapshot of one queued retry for persistence.
class MutationRetryPersistedEntry {
  final String id;
  final bool idempotent;
  final String? label;
  final DateTime? nextRetryAt;
  final int attemptCount;
  final MutationRetryPersistedPayload payload;

  const MutationRetryPersistedEntry({
    required this.id,
    required this.idempotent,
    required this.label,
    required this.nextRetryAt,
    required this.attemptCount,
    required this.payload,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'idempotent': idempotent,
        'label': label,
        'nextRetryAt': nextRetryAt?.toIso8601String(),
        'attemptCount': attemptCount,
        'opKey': payload.opKey,
        'args': payload.args,
      };

  factory MutationRetryPersistedEntry.fromJson(Map<String, Object?> json) {
    return MutationRetryPersistedEntry(
      id: json['id']! as String,
      idempotent: json['idempotent']! as bool,
      label: json['label'] as String?,
      nextRetryAt: json['nextRetryAt'] != null
          ? DateTime.parse(json['nextRetryAt']! as String)
          : null,
      attemptCount: (json['attemptCount'] as num).toInt(),
      payload: MutationRetryPersistedPayload(
        opKey: json['opKey']! as String,
        args: Map<String, Object?>.from(json['args']! as Map),
      ),
    );
  }

  static String encodeList(List<MutationRetryPersistedEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  static List<MutationRetryPersistedEntry> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in list)
        MutationRetryPersistedEntry.fromJson(
          Map<String, Object?>.from(item as Map),
        ),
    ];
  }
}

const mutationRetryPersistenceStateKey =
    r'riverpod_for_serverpod/mutation_retry/v1/state';
