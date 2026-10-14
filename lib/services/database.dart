import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/diet.dart';
import '../models/enums.dart';
import '../models/food.dart';
import '../models/progress.dart';
import '../models/workout.dart';

/// On-device SQLite storage for everything the user records over time.
///
/// All health data stays here. There is no backend and nothing is uploaded.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static const String _fileName = 'trainerapp.db';
  static const int _version = 1;

  static Future<AppDatabase> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, _fileName),
      version: _version,
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, from, to) async {
        // Version 1 is the first release, so there is nothing to migrate yet.
        // Future migrations go here, stepping from `from` up to `to`.
      },
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
    return AppDatabase._(db);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        label_key TEXT NOT NULL,
        muscle_groups TEXT NOT NULL,
        is_light INTEGER NOT NULL DEFAULT 0,
        is_deload INTEGER NOT NULL DEFAULT 0,
        pre_check_note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE exercise_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        exercise_id TEXT NOT NULL,
        exercise_name TEXT NOT NULL,
        position INTEGER NOT NULL,
        feedback TEXT,
        skipped INTEGER NOT NULL DEFAULT 0,
        replaced_exercise_id TEXT,
        sets_json TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_logs_exercise ON exercise_logs(exercise_id)',
    );
    await db.execute(
      'CREATE INDEX idx_logs_session ON exercise_logs(session_id)',
    );

    await db.execute('''
      CREATE TABLE pre_workout_checks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        answered_at TEXT NOT NULL,
        has_problem INTEGER NOT NULL,
        red_flags TEXT NOT NULL,
        outcome TEXT NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE weigh_ins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recorded_at TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        new_health_problem INTEGER NOT NULL DEFAULT 0,
        note TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_weigh_ins_at ON weigh_ins(recorded_at)');

    await db.execute('''
      CREATE TABLE measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recorded_at TEXT NOT NULL,
        waist_cm REAL, chest_cm REAL, hip_cm REAL,
        arm_cm REAL, thigh_cm REAL, neck_cm REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE food_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        logged_at TEXT NOT NULL,
        day TEXT NOT NULL,
        slot TEXT NOT NULL,
        food_id TEXT NOT NULL,
        food_name TEXT NOT NULL,
        grams REAL NOT NULL,
        kcal REAL NOT NULL,
        protein_g REAL NOT NULL,
        carb_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        cost_inr REAL
      )
    ''');
    await db.execute('CREATE INDEX idx_food_logs_day ON food_logs(day)');

    await db.execute('''
      CREATE TABLE water_logs (
        day TEXT PRIMARY KEY,
        millilitres INTEGER NOT NULL
      )
    ''');

    // Prices are entered by the user. The app ships none.
    await db.execute('''
      CREATE TABLE food_prices (
        food_id TEXT PRIMARY KEY,
        price_per_kg_inr REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------- sessions

  /// Start a session and return its id.
  Future<int> startSession({
    required String labelKey,
    required List<String> muscleGroups,
    bool isLight = false,
    bool isDeload = false,
    String? preCheckNote,
  }) => _db.insert('sessions', {
    'started_at': DateTime.now().toIso8601String(),
    'label_key': labelKey,
    'muscle_groups': muscleGroups.join(','),
    'is_light': isLight ? 1 : 0,
    'is_deload': isDeload ? 1 : 0,
    'pre_check_note': preCheckNote,
  });

  Future<void> finishSession(int sessionId) => _db.update(
    'sessions',
    {'finished_at': DateTime.now().toIso8601String()},
    where: 'id = ?',
    whereArgs: [sessionId],
  );

  /// Discard a session that was abandoned before anything was logged.
  Future<void> deleteSession(int sessionId) =>
      _db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);

  Future<void> saveExerciseLog({
    required int sessionId,
    required int position,
    required ExerciseLog log,
  }) async {
    await _db.insert('exercise_logs', {
      'session_id': sessionId,
      'exercise_id': log.exerciseId,
      'exercise_name': log.exerciseName,
      'position': position,
      'feedback': log.feedback?.name,
      'skipped': log.skipped ? 1 : 0,
      'replaced_exercise_id': log.replacedExerciseId,
      'sets_json': jsonEncode(log.sets.map((s) => s.toJson()).toList()),
    });
  }

  /// Finished sessions, newest first.
  Future<List<WorkoutSession>> sessionHistory({int limit = 100}) async {
    final rows = await _db.query(
      'sessions',
      where: 'finished_at IS NOT NULL',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return Future.wait(rows.map(_hydrateSession));
  }

  Future<WorkoutSession?> sessionById(int id) async {
    final rows = await _db.query('sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _hydrateSession(rows.first);
  }

  Future<WorkoutSession> _hydrateSession(Map<String, Object?> row) async {
    final id = row['id'] as int;
    final logRows = await _db.query(
      'exercise_logs',
      where: 'session_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );

    return WorkoutSession(
      id: id,
      startedAt: DateTime.parse(row['started_at'] as String),
      finishedAt:
          row['finished_at'] == null
              ? null
              : DateTime.tryParse(row['finished_at'] as String),
      labelKey: row['label_key'] as String,
      muscleGroups:
          (row['muscle_groups'] as String)
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList(),
      isLightSession: (row['is_light'] as int? ?? 0) == 1,
      isDeload: (row['is_deload'] as int? ?? 0) == 1,
      preCheckNote: row['pre_check_note'] as String?,
      logs: [
        for (final l in logRows)
          ExerciseLog(
            exerciseId: l['exercise_id'] as String,
            exerciseName: l['exercise_name'] as String,
            feedback:
                l['feedback'] == null
                    ? null
                    : SetFeedback.fromName(l['feedback'] as String),
            skipped: (l['skipped'] as int? ?? 0) == 1,
            replacedExerciseId: l['replaced_exercise_id'] as String?,
            sets:
                (jsonDecode(l['sets_json'] as String) as List)
                    .map(
                      (e) =>
                          SetLog.fromJson((e as Map).cast<String, dynamic>()),
                    )
                    .toList(),
          ),
      ],
    );
  }

  /// The most recent completed log for one exercise, which the progression
  /// engine uses to decide the next session.
  Future<ExerciseLog?> lastLogFor(String exerciseId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT l.* FROM exercise_logs l
      JOIN sessions s ON s.id = l.session_id
      WHERE l.exercise_id = ? AND l.skipped = 0 AND s.finished_at IS NOT NULL
      ORDER BY s.started_at DESC LIMIT 1
    ''',
      [exerciseId],
    );
    if (rows.isEmpty) return null;
    final l = rows.first;
    return ExerciseLog(
      exerciseId: l['exercise_id'] as String,
      exerciseName: l['exercise_name'] as String,
      feedback:
          l['feedback'] == null
              ? null
              : SetFeedback.fromName(l['feedback'] as String),
      skipped: false,
      sets:
          (jsonDecode(l['sets_json'] as String) as List)
              .map((e) => SetLog.fromJson((e as Map).cast<String, dynamic>()))
              .toList(),
    );
  }

  /// Latest log for every exercise the user has ever done, in one query, so
  /// building a plan does not fan out into dozens of round trips.
  Future<Map<String, ExerciseLog>> latestLogsByExercise() async {
    final rows = await _db.rawQuery('''
      SELECT l.* FROM exercise_logs l
      JOIN sessions s ON s.id = l.session_id
      WHERE l.skipped = 0 AND s.finished_at IS NOT NULL
      ORDER BY s.started_at DESC
    ''');
    final out = <String, ExerciseLog>{};
    for (final l in rows) {
      final id = l['exercise_id'] as String;
      if (out.containsKey(id)) continue; // rows are newest first
      out[id] = ExerciseLog(
        exerciseId: id,
        exerciseName: l['exercise_name'] as String,
        feedback:
            l['feedback'] == null
                ? null
                : SetFeedback.fromName(l['feedback'] as String),
        sets:
            (jsonDecode(l['sets_json'] as String) as List)
                .map((e) => SetLog.fromJson((e as Map).cast<String, dynamic>()))
                .toList(),
      );
    }
    return out;
  }

  /// Dates (local, midnight-normalised) on which a session was completed.
  Future<Set<DateTime>> completedSessionDays({int limit = 400}) async {
    final rows = await _db.query(
      'sessions',
      columns: ['started_at'],
      where: 'finished_at IS NOT NULL',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return {
      for (final r in rows)
        () {
          final d = DateTime.parse(r['started_at'] as String);
          return DateTime(d.year, d.month, d.day);
        }(),
    };
  }

  Future<List<PersonalRecord>> personalRecords() async {
    final rows = await _db.rawQuery('''
      SELECT l.exercise_id, l.exercise_name, l.sets_json, s.started_at
      FROM exercise_logs l
      JOIN sessions s ON s.id = l.session_id
      WHERE l.skipped = 0 AND s.finished_at IS NOT NULL
    ''');

    final best = <String, PersonalRecord>{};
    for (final r in rows) {
      final id = r['exercise_id'] as String;
      final at = DateTime.parse(r['started_at'] as String);
      final sets =
          (jsonDecode(r['sets_json'] as String) as List)
              .map((e) => SetLog.fromJson((e as Map).cast<String, dynamic>()))
              .where((s) => s.completed)
              .toList();
      if (sets.isEmpty) continue;

      double? topWeight;
      int? topReps;
      int? topSeconds;
      double topVolume = 0;
      for (final s in sets) {
        final w = s.weightKg;
        if (w != null && (topWeight == null || w > topWeight)) topWeight = w;
        if (topReps == null || s.reps > topReps) topReps = s.reps;
        final sec = s.seconds;
        if (sec != null && (topSeconds == null || sec > topSeconds)) {
          topSeconds = sec;
        }
        topVolume += s.volume;
      }

      final existing = best[id];
      final better =
          existing == null ||
          (topWeight ?? 0) > (existing.bestWeightKg ?? 0) ||
          ((topWeight ?? 0) == (existing.bestWeightKg ?? 0) &&
              topVolume > (existing.bestVolume ?? 0));
      if (better) {
        best[id] = PersonalRecord(
          exerciseId: id,
          exerciseName: r['exercise_name'] as String,
          achievedAt: at,
          bestWeightKg: topWeight,
          bestReps: topReps,
          bestSeconds: topSeconds,
          bestVolume: topVolume,
        );
      }
    }

    final list =
        best.values.toList()
          ..sort((a, b) => a.exerciseName.compareTo(b.exerciseName));
    return list;
  }

  // ----------------------------------------------------- pre-workout checks

  Future<void> savePreWorkoutCheck(PreWorkoutCheck check) =>
      _db.insert('pre_workout_checks', {
        'answered_at': check.answeredAt.toIso8601String(),
        'has_problem': check.hasProblem ? 1 : 0,
        'red_flags': check.redFlags.join(','),
        'outcome': check.outcome.name,
        'note': check.note,
      });

  Future<List<PreWorkoutCheck>> preWorkoutChecks({int limit = 100}) async {
    final rows = await _db.query(
      'pre_workout_checks',
      orderBy: 'answered_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (r) => PreWorkoutCheck(
            answeredAt: DateTime.parse(r['answered_at'] as String),
            hasProblem: (r['has_problem'] as int) == 1,
            redFlags:
                (r['red_flags'] as String)
                    .split(',')
                    .where((s) => s.isNotEmpty)
                    .toList(),
            outcome: PreWorkoutOutcome.values.firstWhere(
              (e) => e.name == r['outcome'],
              orElse: () => PreWorkoutOutcome.proceedNormal,
            ),
            note: r['note'] as String?,
          ),
        )
        .toList();
  }

  // --------------------------------------------------------------- weigh-ins

  Future<int> addWeighIn({
    required double weightKg,
    required bool newHealthProblem,
    String? note,
    DateTime? at,
  }) => _db.insert('weigh_ins', {
    'recorded_at': (at ?? DateTime.now()).toIso8601String(),
    'weight_kg': weightKg,
    'new_health_problem': newHealthProblem ? 1 : 0,
    'note': note,
  });

  /// Newest first, which is what the trend logic expects.
  Future<List<WeighIn>> weighIns({int limit = 200}) async {
    final rows = await _db.query(
      'weigh_ins',
      orderBy: 'recorded_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (r) => WeighIn(
            id: r['id'] as int,
            recordedAt: DateTime.parse(r['recorded_at'] as String),
            weightKg: (r['weight_kg'] as num).toDouble(),
            newHealthProblem: (r['new_health_problem'] as int? ?? 0) == 1,
            note: r['note'] as String?,
          ),
        )
        .toList();
  }

  // ------------------------------------------------------------ measurements

  Future<int> addMeasurement(BodyMeasurement m) => _db.insert('measurements', {
    'recorded_at': m.recordedAt.toIso8601String(),
    'waist_cm': m.waistCm,
    'chest_cm': m.chestCm,
    'hip_cm': m.hipCm,
    'arm_cm': m.armCm,
    'thigh_cm': m.thighCm,
    'neck_cm': m.neckCm,
  });

  Future<List<BodyMeasurement>> measurements({int limit = 200}) async {
    final rows = await _db.query(
      'measurements',
      orderBy: 'recorded_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (r) => BodyMeasurement(
            id: r['id'] as int,
            recordedAt: DateTime.parse(r['recorded_at'] as String),
            waistCm: (r['waist_cm'] as num?)?.toDouble(),
            chestCm: (r['chest_cm'] as num?)?.toDouble(),
            hipCm: (r['hip_cm'] as num?)?.toDouble(),
            armCm: (r['arm_cm'] as num?)?.toDouble(),
            thighCm: (r['thigh_cm'] as num?)?.toDouble(),
            neckCm: (r['neck_cm'] as num?)?.toDouble(),
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------- food log

  Future<int> logFood({
    required MealSlot slot,
    required MealItem item,
    DateTime? at,
  }) {
    final when = at ?? DateTime.now();
    return _db.insert('food_logs', {
      'logged_at': when.toIso8601String(),
      'day': _dayKey(when),
      'slot': slot.name,
      'food_id': item.foodId,
      'food_name': item.foodName,
      'grams': item.grams,
      'kcal': item.kcal,
      'protein_g': item.proteinG,
      'carb_g': item.carbG,
      'fat_g': item.fatG,
      'cost_inr': item.costInr,
    });
  }

  Future<void> deleteFoodLog(int id) =>
      _db.delete('food_logs', where: 'id = ?', whereArgs: [id]);

  Future<List<FoodLogEntry>> foodLogsForDay(DateTime day) async {
    final rows = await _db.query(
      'food_logs',
      where: 'day = ?',
      whereArgs: [_dayKey(day)],
      orderBy: 'logged_at ASC',
    );
    return rows
        .map(
          (r) => FoodLogEntry(
            id: r['id'] as int,
            loggedAt: DateTime.parse(r['logged_at'] as String),
            slot: MealSlot.fromName(r['slot'] as String),
            item: MealItem(
              foodId: r['food_id'] as String,
              foodName: r['food_name'] as String,
              grams: (r['grams'] as num).toDouble(),
              kcal: (r['kcal'] as num).toDouble(),
              proteinG: (r['protein_g'] as num).toDouble(),
              carbG: (r['carb_g'] as num).toDouble(),
              fatG: (r['fat_g'] as num).toDouble(),
              costInr: (r['cost_inr'] as num?)?.toDouble(),
            ),
          ),
        )
        .toList();
  }

  Future<DayNutritionTotals> totalsForDay(DateTime day) async {
    final rows = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS n, SUM(kcal) AS kcal, SUM(protein_g) AS p,
             SUM(carb_g) AS c, SUM(fat_g) AS f
      FROM food_logs WHERE day = ?
    ''',
      [_dayKey(day)],
    );
    final r = rows.first;
    final n = (r['n'] as num?)?.toInt() ?? 0;
    if (n == 0) return DayNutritionTotals.empty;
    return DayNutritionTotals(
      kcal: (r['kcal'] as num?)?.toDouble() ?? 0,
      proteinG: (r['p'] as num?)?.toDouble() ?? 0,
      carbG: (r['c'] as num?)?.toDouble() ?? 0,
      fatG: (r['f'] as num?)?.toDouble() ?? 0,
      entryCount: n,
    );
  }

  // --------------------------------------------------------------- water log

  Future<int> waterForDay(DateTime day) async {
    final rows = await _db.query(
      'water_logs',
      where: 'day = ?',
      whereArgs: [_dayKey(day)],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['millilitres'] as num).toInt();
  }

  /// Add (or subtract) water for a day. Never goes below zero.
  Future<int> addWater(DateTime day, int millilitres) async {
    final current = await waterForDay(day);
    final next = (current + millilitres).clamp(0, 20000);
    await _db.insert('water_logs', {
      'day': _dayKey(day),
      'millilitres': next,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return next;
  }

  Future<Map<String, int>> allWaterLogs() async {
    final rows = await _db.query('water_logs', orderBy: 'day DESC');
    return {
      for (final r in rows)
        r['day'] as String: (r['millilitres'] as num).toInt(),
    };
  }

  // ------------------------------------------------------------ food prices

  Future<void> setFoodPrice(String foodId, double pricePerKgInr) =>
      _db.insert('food_prices', {
        'food_id': foodId,
        'price_per_kg_inr': pricePerKgInr,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteFoodPrice(String foodId) =>
      _db.delete('food_prices', where: 'food_id = ?', whereArgs: [foodId]);

  Future<Map<String, FoodPrice>> foodPrices() async {
    final rows = await _db.query('food_prices');
    return {
      for (final r in rows)
        r['food_id'] as String: FoodPrice(
          foodId: r['food_id'] as String,
          pricePerKgInr: (r['price_per_kg_inr'] as num).toDouble(),
          updatedAt: DateTime.parse(r['updated_at'] as String),
        ),
    };
  }

  // ----------------------------------------------------------- export, wipe

  /// Everything in the database, for "export my data".
  Future<Map<String, dynamic>> exportAll() async {
    Future<List<Map<String, Object?>>> all(String table) => _db.query(table);

    return {
      'sessions': await all('sessions'),
      'exerciseLogs': await all('exercise_logs'),
      'preWorkoutChecks': await all('pre_workout_checks'),
      'weighIns': await all('weigh_ins'),
      'measurements': await all('measurements'),
      'foodLogs': await all('food_logs'),
      'waterLogs': await all('water_logs'),
      'foodPrices': await all('food_prices'),
    };
  }

  /// Delete every row the user ever created. Used by "delete all my data".
  Future<void> deleteEverything() async {
    await _db.transaction((txn) async {
      for (final table in [
        'exercise_logs',
        'sessions',
        'pre_workout_checks',
        'weigh_ins',
        'measurements',
        'food_logs',
        'water_logs',
        'food_prices',
      ]) {
        await txn.delete(table);
      }
    });
  }

  Future<void> close() => _db.close();
}
