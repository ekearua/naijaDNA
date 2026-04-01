import 'dart:math';

import 'package:drift/drift.dart';
import 'package:naijapulse/core/storage/app_database.dart';

class PendingPollVote {
  const PendingPollVote({
    required this.id,
    required this.voteId,
    required this.pollId,
    required this.optionId,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });

  final int id;
  final String voteId;
  final String pollId;
  final String optionId;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
}

abstract class PollVoteOutboxLocalDataSource {
  Future<PendingPollVote> enqueueVote({
    required String pollId,
    required String optionId,
    String? voteId,
  });

  Future<List<PendingPollVote>> getPendingVotes({int limit = 50});

  Future<void> removeVoteById(int id);

  Future<void> clearForPoll(String pollId);

  Future<void> incrementAttempts({
    required int id,
    required String errorMessage,
  });

  Future<int> pendingCount();
}

class PollVoteOutboxLocalDataSourceImpl
    implements PollVoteOutboxLocalDataSource {
  PollVoteOutboxLocalDataSourceImpl({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;
  final Random _random = Random();

  @override
  Future<PendingPollVote> enqueueVote({
    required String pollId,
    required String optionId,
    String? voteId,
  }) async {
    final now = DateTime.now().toUtc();
    final normalizedVoteId = (voteId ?? '').trim();
    final effectiveVoteId = normalizedVoteId.isEmpty
        ? _newVoteId()
        : normalizedVoteId;
    final existing = await (_database.select(
      _database.pollVoteOutboxEntries,
    )..where((tbl) => tbl.pollId.equals(pollId))).getSingleOrNull();

    if (existing != null) {
      if (existing.optionId == optionId) {
        if (existing.voteId == effectiveVoteId) {
          return _toPendingVote(existing);
        }
        await (_database.update(
          _database.pollVoteOutboxEntries,
        )..where((tbl) => tbl.id.equals(existing.id))).write(
          PollVoteOutboxEntriesCompanion(
            voteId: Value(effectiveVoteId),
            createdAt: Value(now),
            attempts: const Value(0),
            lastError: const Value(null),
          ),
        );
        final refreshed = await (_database.select(
          _database.pollVoteOutboxEntries,
        )..where((tbl) => tbl.id.equals(existing.id))).getSingle();
        return _toPendingVote(refreshed);
      }
      await (_database.update(
        _database.pollVoteOutboxEntries,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        PollVoteOutboxEntriesCompanion(
          voteId: Value(effectiveVoteId),
          optionId: Value(optionId),
          createdAt: Value(now),
          attempts: const Value(0),
          lastError: const Value(null),
        ),
      );

      final refreshed = await (_database.select(
        _database.pollVoteOutboxEntries,
      )..where((tbl) => tbl.id.equals(existing.id))).getSingle();
      return _toPendingVote(refreshed);
    }

    final rowId = await _database
        .into(_database.pollVoteOutboxEntries)
        .insert(
          PollVoteOutboxEntriesCompanion.insert(
            voteId: effectiveVoteId,
            pollId: pollId,
            optionId: optionId,
            createdAt: now,
          ),
        );
    return PendingPollVote(
      id: rowId,
      voteId: effectiveVoteId,
      pollId: pollId,
      optionId: optionId,
      createdAt: now,
      attempts: 0,
    );
  }

  @override
  Future<List<PendingPollVote>> getPendingVotes({int limit = 50}) async {
    final rows =
        await (_database.select(_database.pollVoteOutboxEntries)
              ..orderBy([
                (tbl) => OrderingTerm.asc(tbl.createdAt),
                (tbl) => OrderingTerm.asc(tbl.id),
              ])
              ..limit(limit))
            .get();
    return rows.map(_toPendingVote).toList();
  }

  @override
  Future<void> removeVoteById(int id) async {
    await (_database.delete(
      _database.pollVoteOutboxEntries,
    )..where((tbl) => tbl.id.equals(id))).go();
  }

  @override
  Future<void> clearForPoll(String pollId) async {
    await (_database.delete(
      _database.pollVoteOutboxEntries,
    )..where((tbl) => tbl.pollId.equals(pollId))).go();
  }

  @override
  Future<void> incrementAttempts({
    required int id,
    required String errorMessage,
  }) async {
    await (_database.customUpdate(
      '''
      UPDATE poll_vote_outbox_entries
      SET attempts = attempts + 1,
          last_error = ?
      WHERE id = ?
      ''',
      variables: [Variable.withString(errorMessage), Variable.withInt(id)],
      updates: {_database.pollVoteOutboxEntries},
    ));
  }

  @override
  Future<int> pendingCount() async {
    final countExpr = _database.pollVoteOutboxEntries.id.count();
    final query = _database.selectOnly(_database.pollVoteOutboxEntries)
      ..addColumns([countExpr]);
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  PendingPollVote _toPendingVote(PollVoteOutboxEntry row) {
    return PendingPollVote(
      id: row.id,
      voteId: row.voteId,
      pollId: row.pollId,
      optionId: row.optionId,
      createdAt: row.createdAt,
      attempts: row.attempts,
      lastError: row.lastError,
    );
  }

  String _newVoteId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final randomPart = _random.nextInt(0x7fffffff).toRadixString(16);
    return 'vote-$now-$randomPart';
  }
}
