import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'muscle_wiki_service.dart';

/// Sqflite-backed cache for MuscleWikiExercise objects.
/// Stores id, name, steps, videos, primaryMuscles, category, difficulty, muscleSlug.
class ExerciseCacheDb {
  ExerciseCacheDb._();
  static final ExerciseCacheDb instance = ExerciseCacheDb._();

  static Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'exercise_cache.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
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
      },
    );
  }

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
}
