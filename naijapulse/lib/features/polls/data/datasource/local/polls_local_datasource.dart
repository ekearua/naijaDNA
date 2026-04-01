import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:naijapulse/core/storage/app_database.dart';
import 'package:naijapulse/features/polls/data/models/poll_model.dart';

abstract class PollsLocalDataSource {
  Future<void> cacheActivePolls(List<PollModel> polls);

  Future<List<PollModel>> getCachedActivePolls();

  Future<void> cacheUpdatedPoll(PollModel poll);
}

class PollsLocalDataSourceImpl implements PollsLocalDataSource {
  final AppDatabase _database;

  PollsLocalDataSourceImpl({required AppDatabase database})
    : _database = database;

  @override
  Future<void> cacheActivePolls(List<PollModel> polls) async {
    await _database.transaction(() async {
      // Active polls are replaced as one set to prevent stale/closed polls lingering.
      await _database.delete(_database.pollCacheEntries).go();

      await _database.batch((batch) {
        for (var index = 0; index < polls.length; index++) {
          final poll = polls[index];
          batch.insert(
            _database.pollCacheEntries,
            PollCacheEntriesCompanion.insert(
              pollId: poll.id,
              question: poll.question,
              optionsJson: _encodeOptions(poll),
              endsAt: poll.endsAt,
              hasVoted: Value(poll.hasVoted),
              selectedOptionId: Value(poll.selectedOptionId),
              sortOrder: index,
            ),
          );
        }
      });
    });
  }

  @override
  Future<List<PollModel>> getCachedActivePolls() async {
    final query = _database.select(_database.pollCacheEntries)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]);
    final rows = await query.get();
    return rows.map(_toPollModel).toList();
  }

  @override
  Future<void> cacheUpdatedPoll(PollModel poll) async {
    // Preserve existing order when patching a single poll after a vote.
    final existing = await (_database.select(
      _database.pollCacheEntries,
    )..where((tbl) => tbl.pollId.equals(poll.id))).getSingleOrNull();
    final sortOrder = existing?.sortOrder ?? await _nextSortOrder();

    await _database
        .into(_database.pollCacheEntries)
        .insertOnConflictUpdate(
          PollCacheEntriesCompanion(
            pollId: Value(poll.id),
            question: Value(poll.question),
            optionsJson: Value(_encodeOptions(poll)),
            endsAt: Value(poll.endsAt),
            hasVoted: Value(poll.hasVoted),
            selectedOptionId: Value(poll.selectedOptionId),
            sortOrder: Value(sortOrder),
          ),
        );
  }

  Future<int> _nextSortOrder() async {
    // Append newly discovered poll ids after existing cached rows.
    final row =
        await (_database.select(_database.pollCacheEntries)
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    return (row?.sortOrder ?? -1) + 1;
  }

  PollModel _toPollModel(PollCacheEntry row) {
    final rawOptions = jsonDecode(row.optionsJson) as List<dynamic>;
    final options = rawOptions
        .map(
          (option) => PollOptionModel.fromJson(option as Map<String, dynamic>),
        )
        .toList();
    return PollModel(
      id: row.pollId,
      question: row.question,
      options: options,
      endsAt: row.endsAt,
      hasVoted: row.hasVoted,
      selectedOptionId: row.selectedOptionId,
    );
  }

  String _encodeOptions(PollModel poll) {
    return jsonEncode(
      poll.options
          .map((option) => PollOptionModel.fromEntity(option).toJson())
          .toList(),
    );
  }
}
