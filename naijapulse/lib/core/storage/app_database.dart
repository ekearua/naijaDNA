import 'package:drift/drift.dart';
import 'package:naijapulse/core/storage/app_database_connection.dart';

part 'app_database.g.dart';

class NewsCacheEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bucket => text()();
  TextColumn get requestCategory => text().nullable()();
  IntColumn get sortOrder => integer()();
  TextColumn get articleId => text()();
  TextColumn get title => text()();
  TextColumn get source => text()();
  TextColumn get articleCategory => text()();
  TextColumn get summary => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get articleUrl => text().nullable()();
  DateTimeColumn get publishedAt => dateTime()();
  BoolColumn get isFactChecked =>
      boolean().withDefault(const Constant(false))();

  @override
  // De-duplicate by feed slice and article identity.
  List<Set<Column<Object>>>? get uniqueKeys => [
    {bucket, requestCategory, articleId},
  ];
}

class PollCacheEntries extends Table {
  TextColumn get pollId => text()();
  TextColumn get question => text()();
  TextColumn get optionsJson => text()();
  DateTimeColumn get endsAt => dateTime()();
  BoolColumn get hasVoted => boolean().withDefault(const Constant(false))();
  TextColumn get selectedOptionId => text().nullable()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>>? get primaryKey => {pollId};
}

class PollVoteOutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get voteId => text()();
  TextColumn get pollId => text()();
  TextColumn get optionId => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  List<Set<Column<Object>>>? get uniqueKeys => [
    {voteId},
    // Keep one pending vote per poll to avoid duplicate offline replays.
    {pollId},
  ];
}

@DriftDatabase(
  tables: [NewsCacheEntries, PollCacheEntries, PollVoteOutboxEntries],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  // Bump when table definitions change and add migrations accordingly.
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(pollVoteOutboxEntries);
      }
    },
  );
}
