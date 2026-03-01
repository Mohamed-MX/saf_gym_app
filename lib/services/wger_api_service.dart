import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exercise.dart';

class WgerApiService {
  static const String _baseUrl = 'https://wger.de/api/v2';
  static const int _englishLanguageId = 2;

  /// Fetches all exercise categories (Abs, Arms, Back, etc.)
  Future<List<ExerciseCategory>> getCategories() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/exercisecategory/?format=json'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;
      return results.map((c) => ExerciseCategory.fromJson(c)).toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }

  /// Fetches exercise info with full details (translations, images, muscles)
  Future<Exercise> getExerciseInfo(int id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/exerciseinfo/$id/?format=json'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Exercise.fromExerciseInfo(data);
    } else {
      throw Exception('Failed to load exercise info');
    }
  }

  /// Fetches a paginated list of exercises (basic data)
  Future<List<Map<String, dynamic>>> getExerciseIds({
    int? category,
    int limit = 20,
    int offset = 0,
  }) async {
    String url = '$_baseUrl/exercise/?format=json'
        '&language=$_englishLanguageId'
        '&limit=$limit'
        '&offset=$offset';

    if (category != null) {
      url += '&category=$category';
    }

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Failed to load exercises');
    }
  }

  /// Fetches exercises by category with full info
  Future<List<Exercise>> getExercisesByCategory(int categoryId,
      {int limit = 20}) async {
    final exerciseData =
        await getExerciseIds(category: categoryId, limit: limit);
    final exercises = <Exercise>[];

    for (var data in exerciseData) {
      try {
        final exercise = await getExerciseInfo(data['id']);
        if (exercise.name.isNotEmpty &&
            !exercise.name.startsWith('Exercise #')) {
          exercises.add(exercise);
        }
      } catch (e) {
        // Skip exercises that fail to load
      }
    }

    return exercises;
  }

  /// Fetches a list of exercises by their IDs with full info
  Future<List<Exercise>> getExercisesByIds(List<int> ids) async {
    final exercises = <Exercise>[];

    for (var id in ids) {
      try {
        final exercise = await getExerciseInfo(id);
        if (exercise.name.isNotEmpty &&
            !exercise.name.startsWith('Exercise #')) {
          exercises.add(exercise);
        }
      } catch (e) {
        // Skip exercises that fail to load
      }
    }

    return exercises;
  }

  /// Fetches all muscles
  Future<List<Muscle>> getMuscles() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/muscle/?format=json'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;
      return results.map((m) => Muscle.fromJson(m)).toList();
    } else {
      throw Exception('Failed to load muscles');
    }
  }

  /// Fetches all equipment types
  Future<List<Equipment>> getEquipment() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/equipment/?format=json'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;
      return results.map((e) => Equipment.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load equipment');
    }
  }

  /// Search exercises by term
  Future<List<Exercise>> searchExercises(String term) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/exercise/search/?term=$term&language=english&format=json'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final suggestions = data['suggestions'] as List? ?? [];
      final exercises = <Exercise>[];

      for (var suggestion in suggestions.take(10)) {
        final exerciseData = suggestion['data'];
        if (exerciseData != null && exerciseData['id'] != null) {
          try {
            final exercise = await getExerciseInfo(exerciseData['id']);
            exercises.add(exercise);
          } catch (e) {
            // Skip failed exercises
          }
        }
      }

      return exercises;
    } else {
      throw Exception('Failed to search exercises');
    }
  }
}
