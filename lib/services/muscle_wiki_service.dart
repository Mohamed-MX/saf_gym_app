import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ── MuscleCategory ─────────────────────────────────────────────────────────

class MuscleCategory {
  final String muscleName; // As accepted by the API (e.g. "Chest")
  final String displayName; // Human-friendly label
  final IconData icon;

  const MuscleCategory({
    required this.muscleName,
    required this.displayName,
    required this.icon,
  });
}

// ── MuscleWikiExercise ─────────────────────────────────────────────────────

class MuscleWikiExercise {
  final int id;
  final String name;
  final List<String> primaryMuscles;
  /// Equipment category from the API (e.g. "Barbell", "Dumbbells")
  final String? category;
  final String? difficulty;
  final List<String> steps;
  /// thumbnail image URL from the first video's og_image
  final String? thumbnailUrl;
  /// video URL from the first male-front video
  final String? gifUrl;
  /// Muscle slug this exercise was fetched under (for display badges)
  final String? muscleSlug;

  MuscleWikiExercise({
    required this.id,
    required this.name,
    required this.primaryMuscles,
    this.category,
    this.difficulty,
    required this.steps,
    this.thumbnailUrl,
    this.gifUrl,
    this.muscleSlug,
  });

  String? get displayImageUrl => thumbnailUrl ?? gifUrl;

  String get primaryMusclesLabel =>
      primaryMuscles.isEmpty ? '' : primaryMuscles.join(', ');

  factory MuscleWikiExercise.fromJson(Map<String, dynamic> json) {
    // primary_muscles is a list of strings like ["Chest"]
    final muscles = (json['primary_muscles'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // steps is a list of strings
    final steps = (json['steps'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // Pull first male-front video for preview, fall back to first video
    String? gifUrl;
    String? thumbnailUrl;
    final videos = json['videos'] as List<dynamic>?;
    if (videos != null && videos.isNotEmpty) {
      // prefer male front
      final maleFront = videos.firstWhere(
        (v) =>
            v['gender'] == 'male' && v['angle'] == 'front',
        orElse: () => videos.first,
      );
      gifUrl = maleFront['url'] as String?;
      thumbnailUrl = maleFront['og_image'] as String?;
    }

    return MuscleWikiExercise(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      primaryMuscles: muscles,
      category: json['category'] as String?,
      difficulty: json['difficulty'] as String?,
      steps: steps,
      thumbnailUrl: thumbnailUrl,
      gifUrl: gifUrl,
      muscleSlug: json['_muscleSlug'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primary_muscles': primaryMuscles,
        if (category != null) 'category': category,
        if (difficulty != null) 'difficulty': difficulty,
        'steps': steps,
        if (thumbnailUrl != null) 'og_image': thumbnailUrl,
        if (gifUrl != null) 'url': gifUrl,
        if (muscleSlug != null) '_muscleSlug': muscleSlug,
        // Wrap back into the videos list format so fromJson can re-parse
        if (gifUrl != null || thumbnailUrl != null)
          'videos': [
            {
              'url': gifUrl,
              'og_image': thumbnailUrl,
              'gender': 'male',
              'angle': 'front',
            }
          ],
      };

  MuscleWikiExercise withSlug(String slug) => MuscleWikiExercise(
        id: id,
        name: name,
        primaryMuscles: primaryMuscles,
        category: category,
        difficulty: difficulty,
        steps: steps,
        thumbnailUrl: thumbnailUrl,
        gifUrl: gifUrl,
        muscleSlug: slug,
      );
}

// ── MuscleWikiService ──────────────────────────────────────────────────────

class MuscleWikiService {
  static const String _baseUrl = 'https://api.musclewiki.com';
  static const String _apiKey =
      'REDACTED_KEY';

  static const Map<String, String> _headers = {
    'X-API-Key': _apiKey,
    'Content-Type': 'application/json',
  };

  // ── Muscle name → API query value (capitalized as the API expects) ──────
  static const Map<String, String> muscleSlugMap = {
    'abdominals': 'Abdominals',
    'obliques': 'Abdominals',
    'chest': 'Chest',
    'front-shoulders': 'Front Shoulders',
    'biceps': 'Biceps',
    'forearms': 'Forearms',
    'quads': 'Quads',
    'calves': 'Calves',
    'traps': 'Traps',
    'lats': 'Lats',
    'rear-shoulders': 'Rear Delts',
    'triceps': 'Triceps',
    'hamstrings': 'Hamstrings',
    'glutes': 'Glutes',
    'lower-back': 'Lower Back',
    'traps-middle': 'Traps',
  };

  static const Map<String, String> muscleDisplayNames = {
    'abdominals': 'Abs',
    'obliques': 'Obliques',
    'chest': 'Chest',
    'front-shoulders': 'Front Delts',
    'biceps': 'Biceps',
    'forearms': 'Forearms',
    'quads': 'Quads',
    'calves': 'Calves',
    'traps': 'Traps',
    'lats': 'Lats',
    'rear-shoulders': 'Rear Delts',
    'triceps': 'Triceps',
    'hamstrings': 'Hamstrings',
    'glutes': 'Glutes',
    'lower-back': 'Lower Back',
    'traps-middle': 'Mid Traps',
  };

  // ── Categories shown in the grid (slug → display name + icon) ──────────
  static const List<MuscleCategory> _allCategories = [
    MuscleCategory(muscleName: 'Chest', displayName: 'Chest', icon: Icons.fitness_center),
    MuscleCategory(muscleName: 'Lats', displayName: 'Lats', icon: Icons.accessibility_new),
    MuscleCategory(muscleName: 'Biceps', displayName: 'Biceps', icon: Icons.sports_gymnastics),
    MuscleCategory(muscleName: 'Triceps', displayName: 'Triceps', icon: Icons.sports_gymnastics),
    MuscleCategory(muscleName: 'Front Shoulders', displayName: 'Shoulders', icon: Icons.person),
    MuscleCategory(muscleName: 'Abdominals', displayName: 'Abs', icon: Icons.sports_martial_arts),
    MuscleCategory(muscleName: 'Quads', displayName: 'Quads', icon: Icons.directions_run),
    MuscleCategory(muscleName: 'Hamstrings', displayName: 'Hamstrings', icon: Icons.directions_run),
    MuscleCategory(muscleName: 'Glutes', displayName: 'Glutes', icon: Icons.directions_walk),
    MuscleCategory(muscleName: 'Calves', displayName: 'Calves', icon: Icons.directions_walk),
    MuscleCategory(muscleName: 'Traps', displayName: 'Traps', icon: Icons.accessibility),
    MuscleCategory(muscleName: 'Lower Back', displayName: 'Lower Back', icon: Icons.accessibility),
  ];

  // ── Daily workout muscles ───────────────────────────────────────────────
  static const List<String> _workoutMuscles = [
    'Chest', 'Lats', 'Biceps', 'Triceps',
    'Front Shoulders', 'Abdominals', 'Quads',
    'Hamstrings', 'Glutes', 'Calves', 'Traps',
  ];

  // ── Public API ──────────────────────────────────────────────────────────

  List<MuscleCategory> getMuscleCategories() => _allCategories;

  /// Fetch exercises by muscle name (uses the API's exact capitalized name)
  Future<List<MuscleWikiExercise>> getExercisesByMuscle({
    required String muscle,
    int limit = 20,
  }) async {
    // `muscle` may be our internal slug or the API's display name
    final apiMuscle = muscleSlugMap[muscle] ?? muscle;

    final uri = Uri.parse('$_baseUrl/exercises').replace(
      queryParameters: {
        'muscles': apiMuscle,
        'limit': '$limit',
        'detail': 'true',
      },
    );

    try {
      final resp =
          await http.get(uri, headers: _headers).timeout(
        const Duration(seconds: 15),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        return results
            .map((j) =>
                MuscleWikiExercise.fromJson(j as Map<String, dynamic>)
                    .withSlug(muscle))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Daily workout: picks 3 muscle groups seeded by date → ≤9 exercises
  Future<List<MuscleWikiExercise>> getDailyWorkoutExercises({
    DateTime? date,
  }) async {
    final today = date ?? DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final rng = Random(seed);

    final muscles = List<String>.from(_workoutMuscles)..shuffle(rng);
    final picked = muscles.take(3).toList();

    final futures =
        picked.map((m) => getExercisesByMuscle(muscle: m, limit: 3));
    final results = await Future.wait(futures);
    return results.expand((list) => list).toList();
  }

  /// Filtered exercise search for the exercise picker.
  Future<List<MuscleWikiExercise>> getExercisesFiltered({
    String? muscle,
    String? category,
    String? difficulty,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      'detail': 'true',
    };
    if (muscle != null && muscle.isNotEmpty) params['muscles'] = muscle;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (difficulty != null && difficulty.isNotEmpty) {
      params['difficulty'] = difficulty;
    }
    final uri =
        Uri.parse('$_baseUrl/exercises').replace(queryParameters: params);
    try {
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        return results
            .map((j) =>
                MuscleWikiExercise.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<String>> getApiMuscles() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/muscles'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        return list
            .map((e) => (e as Map<String, dynamic>)['name'] as String)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<String>> getApiCategories() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/categories'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        return list
            .map((e) =>
                (e as Map<String, dynamic>)['display_name'] as String)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Static helpers ──────────────────────────────────────────────────────

  static String getDayLabel(DateTime date) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return days[date.weekday - 1];
  }

  static String getDayFocus(DateTime date) {
    const focuses = [
      'Push Day 💪', 'Pull Day 🏋️', 'Leg Day 🦵',
      'Upper Body 💥', 'Full Body 🔥', 'Core & Cardio 🫀',
      'Active Recovery 🧘',
    ];
    return focuses[date.weekday - 1];
  }
}

