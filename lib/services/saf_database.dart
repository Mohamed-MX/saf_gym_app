import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'muscle_wiki_service.dart';
import '../models/workout_plan.dart';

/// Central sqflite database for the SAF Gym App.
/// Replaces `ExerciseCacheDb` and `WorkoutPlanService`.
/// Provides local caching for exercises and persistence for workout plans.
class SafDatabase {
  SafDatabase._();
  static final SafDatabase instance = SafDatabase._();

  static Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'saf_gym.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, _) async {
        // 1. Exercises Table (Cache)
        await db.execute('''
          CREATE TABLE exercises (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            primary_muscles_json TEXT NOT NULL,
            steps_json TEXT NOT NULL,
            videos_json TEXT NOT NULL,
            category TEXT,
            difficulty TEXT,
            muscle_slug TEXT,
            cached_at INTEGER NOT NULL
          )
        ''');

        // 2. Workout Plans Table
        await db.execute('''
          CREATE TABLE workout_plans (
            id TEXT PRIMARY KEY,
            data_json TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');

        // 3. Performance Logs Table
        await db.execute('''
          CREATE TABLE performance_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            date_time INTEGER NOT NULL,
            time_taken_seconds INTEGER NOT NULL,
            workout_name TEXT NOT NULL,
            exercise_name TEXT NOT NULL,
            reps INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE performance_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id INTEGER NOT NULL DEFAULT 0,
              date_time INTEGER NOT NULL,
              time_taken_seconds INTEGER NOT NULL DEFAULT 0,
              workout_name TEXT NOT NULL,
              exercise_name TEXT NOT NULL,
              reps INTEGER NOT NULL
            )
          ''');
        } else if (oldVersion < 3) {
          await db.execute('ALTER TABLE performance_logs ADD COLUMN session_id INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE performance_logs ADD COLUMN time_taken_seconds INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
  }

  // ── Exercises Cache (Replaces ExerciseCacheDb) ──────────────────────────

  /// Returns a cached exercise, or null if not found.
  Future<MuscleWikiExercise?> getExercise(int id) async {
    final db = await _database;
    final rows = await db.query(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToExercise(rows.first);
  }

  /// Inserts or replaces an exercise in the cache.
  Future<void> upsertExercise(MuscleWikiExercise ex) async {
    final db = await _database;
    await db.insert(
      'exercises',
      {
        'id': ex.id,
        'name': ex.name,
        'primary_muscles_json': jsonEncode(ex.primaryMuscles),
        'steps_json': jsonEncode(ex.steps),
        'videos_json': jsonEncode(ex.videos),
        'category': ex.category,
        'difficulty': ex.difficulty,
        'muscle_slug': ex.muscleSlug,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  MuscleWikiExercise _rowToExercise(Map<String, dynamic> row) {
    final muscles = (jsonDecode(row['primary_muscles_json'] as String) as List)
        .map((e) => e.toString())
        .toList();
    final steps = (jsonDecode(row['steps_json'] as String) as List)
        .map((e) => e.toString())
        .toList();
    final rawVideos =
        (jsonDecode(row['videos_json'] as String) as List).map((v) {
      final m = Map<String, dynamic>.from(v as Map);
      return <String, String?>{
        'url': m['url'] as String?,
        'og_image': m['og_image'] as String?,
        'gender': m['gender'] as String?,
        'angle': m['angle'] as String?,
      };
    }).toList();

    // Derive gifUrl / thumbnailUrl from first video
    String? gifUrl;
    String? thumbnailUrl;
    if (rawVideos.isNotEmpty) {
      final first = rawVideos.firstWhere(
        (v) => v['gender'] == 'male' && v['angle'] == 'front',
        orElse: () => rawVideos.first,
      );
      gifUrl = first['url'];
      thumbnailUrl = first['og_image'];
    }

    return MuscleWikiExercise(
      id: row['id'] as int,
      name: row['name'] as String,
      primaryMuscles: muscles,
      steps: steps,
      category: row['category'] as String?,
      difficulty: row['difficulty'] as String?,
      muscleSlug: row['muscle_slug'] as String?,
      thumbnailUrl: thumbnailUrl,
      gifUrl: gifUrl,
      videos: rawVideos,
    );
  }

  // ── Workout Plans (Replaces WorkoutPlanService) ─────────────────────────

  Future<List<WorkoutPlan>> getPlans() async {
    final db = await _database;
    final rows = await db.query(
      'workout_plans',
      orderBy: 'updated_at DESC', // Return newest first
    );
    final plans = <WorkoutPlan>[];
    for (final row in rows) {
      try {
        final plan = WorkoutPlan.fromJson(
            jsonDecode(row['data_json'] as String) as Map<String, dynamic>);
        plans.add(plan);
      } catch (_) {}
    }
    return plans;
  }

  Future<void> savePlan(WorkoutPlan plan) async {
    final db = await _database;
    await db.insert(
      'workout_plans',
      {
        'id': plan.id,
        'data_json': jsonEncode(plan.toJson()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePlan(String planId) async {
    final db = await _database;
    await db.delete(
      'workout_plans',
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  // ── Performance Logs ───────────────────────────────────────────────────

  Future<void> logPerformance(Map<String, dynamic> log) async {
    final db = await _database;
    await db.insert('performance_logs', log);
  }

  Future<List<Map<String, dynamic>>> getPerformanceLogs() async {
    final db = await _database;
    return await db.query('performance_logs', orderBy: 'date_time DESC');
  }
}
