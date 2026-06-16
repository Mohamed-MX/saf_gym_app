import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

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
  final String? category;
  final String? difficulty;
  final List<String> steps;
  final String? thumbnailUrl;
  final String? gifUrl;
  final String? muscleSlug;
  final List<Map<String, String?>> videos;

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
    this.videos = const [],
  });

  String? get displayImageUrl => thumbnailUrl ?? gifUrl;

  String get primaryMusclesLabel =>
      primaryMuscles.isEmpty ? '' : primaryMuscles.join(', ');

  factory MuscleWikiExercise.fromJson(Map<String, dynamic> json) {
    return _mapper(json);
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
        'videos': videos,
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
        videos: videos,
      );

  // Utility mapper
  static MuscleWikiExercise _mapper(Map<String, dynamic> e) {
    String? thumbnailUrl;
    String? gifUrl;
    List<Map<String, String?>> parsedVideos = [];

    if (e['videos'] != null && e['videos'] is List) {
      for (var v in e['videos']) {
        parsedVideos.add({
          'url': v['url']?.toString(),
          'og_image': v['og_image']?.toString(),
          'gender': v['gender']?.toString(),
          'angle': v['angle']?.toString(),
        });
      }
      if (parsedVideos.isNotEmpty) {
        // Prefer male front angle if possible, otherwise just the first video.
        final preferred = parsedVideos.firstWhere(
          (v) => v['gender'] == 'male' && v['angle'] == 'front',
          orElse: () => parsedVideos.first,
        );
        thumbnailUrl = preferred['og_image'];
        gifUrl = preferred['url'];
      }
    } else {
      // Fallback
      thumbnailUrl = e['og_image'];
      gifUrl = e['url'];
    }

    return MuscleWikiExercise(
      id: e['id'] ?? 0,
      name: e['name'] ?? 'Unknown',
      primaryMuscles: List<String>.from(e['primary_muscles'] ?? []),
      category: e['category'] as String?,
      difficulty: e['difficulty'] as String?,
      steps: List<String>.from(e['steps'] ?? []),
      thumbnailUrl: thumbnailUrl,
      gifUrl: gifUrl,
      muscleSlug: e['_muscleSlug'],
      videos: parsedVideos,
    );
  }
}

// ── MuscleWikiService ──────────────────────────────────────────────────────

class MuscleWikiService {
  static const String _baseUrl = 'https://api.musclewiki.com';

  static const Map<String, String> muscleSlugMap = {
    'abdominals': 'Abdominals',
    'obliques': 'Abdominals',
    'chest': 'Chest',
    'front-shoulders': 'Anterior Deltoid',
    'biceps': 'Biceps',
    'forearms': 'Forearms',
    'quads': 'Quads',
    'calves': 'Calves',
    'traps': 'Traps',
    'lats': 'Lats',
    'rear-shoulders': 'Posterior Deltoid',
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

  static const List<MuscleCategory> _allCategories = [
    MuscleCategory(muscleName: 'Chest', displayName: 'Chest', icon: Icons.fitness_center),
    MuscleCategory(muscleName: 'Lats', displayName: 'Lats', icon: Icons.accessibility_new),
    MuscleCategory(muscleName: 'Biceps', displayName: 'Biceps', icon: Icons.sports_gymnastics),
    MuscleCategory(muscleName: 'Triceps', displayName: 'Triceps', icon: Icons.sports_gymnastics),
    MuscleCategory(muscleName: 'Anterior Deltoid', displayName: 'Shoulders', icon: Icons.person),
    MuscleCategory(muscleName: 'Abdominals', displayName: 'Abs', icon: Icons.sports_martial_arts),
    MuscleCategory(muscleName: 'Quads', displayName: 'Quads', icon: Icons.directions_run),
    MuscleCategory(muscleName: 'Hamstrings', displayName: 'Hamstrings', icon: Icons.directions_run),
    MuscleCategory(muscleName: 'Glutes', displayName: 'Glutes', icon: Icons.directions_walk),
    MuscleCategory(muscleName: 'Calves', displayName: 'Calves', icon: Icons.directions_walk),
    MuscleCategory(muscleName: 'Traps', displayName: 'Traps', icon: Icons.accessibility),
    MuscleCategory(muscleName: 'Lower Back', displayName: 'Lower Back', icon: Icons.accessibility),
  ];

  static const List<String> _workoutMuscles = [
    'Chest', 'Lats', 'Biceps', 'Triceps',
    'Anterior Deltoid', 'Abdominals', 'Quads',
    'Hamstrings', 'Glutes', 'Calves', 'Traps',
  ];

  // ── Public API ──────────────────────────────────────────────────────────

  List<MuscleCategory> getMuscleCategories() => _allCategories;

  Future<List<MuscleWikiExercise>> getExercisesByMuscle({
    required String muscle,
    int limit = 20,
  }) async {
    final apiMuscle = muscleSlugMap[muscle] ?? muscle;
    final uri = Uri.parse('$_baseUrl/exercises?muscles=${Uri.encodeQueryComponent(apiMuscle)}&limit=$limit');
    
    try {
      final r = await http.get(uri, headers: AppConfig.apiHeaders).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final resultsList = data['results'] as List;
        
        // The list endpoint only returns id and name. Fetch full details concurrently:
        final futures = resultsList.map((e) => getExerciseById(e['id'], muscleSlug: muscle));
        final detailedList = await Future.wait(futures);
        return detailedList.whereType<MuscleWikiExercise>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<MuscleWikiExercise?> getExerciseById(
    int id, {
    String? muscleSlug,
  }) async {
    final uri = Uri.parse('$_baseUrl/exercises/$id');
    try {
      final r = await http.get(uri, headers: AppConfig.apiHeaders).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final ex = MuscleWikiExercise._mapper(data);
        return muscleSlug != null ? ex.withSlug(muscleSlug) : ex;
      }
    } catch (_) {}
    return null;
  }

  Future<List<MuscleWikiExercise>> getDailyWorkoutExercises({
    DateTime? date,
  }) async {
    final today = date ?? DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final rng = Random(seed);

    final muscles = List<String>.from(_workoutMuscles)..shuffle(rng);
    final picked = muscles.take(3).toList();

    final futures = picked.map((m) => getExercisesByMuscle(muscle: m, limit: 3));
    final results = await Future.wait(futures);
    return results.expand((list) => list).toList();
  }

  Future<List<MuscleWikiExercise>> getExercisesFiltered({
    List<String>? muscles,
    String? category,
    String? difficulty,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    String query = 'limit=$limit&offset=$offset';
    if (search != null && search.isNotEmpty) {
      query += '&search=${Uri.encodeQueryComponent(search)}';
    }
    if (muscles != null && muscles.isNotEmpty) {
      // Just map the first one for simplicity since the API expects a single string for `muscles`.
      final apiMuscle = muscleSlugMap[muscles.first] ?? muscles.first;
      query += '&muscles=${Uri.encodeQueryComponent(apiMuscle)}';
    }
    if (category != null && category.isNotEmpty && category != 'None') {
      query += '&category=${Uri.encodeQueryComponent(category)}';
    }
    if (difficulty != null && difficulty.isNotEmpty && difficulty != 'None') {
      query += '&difficulty=${Uri.encodeQueryComponent(difficulty.toLowerCase())}';
    }

    final uri = Uri.parse('$_baseUrl/exercises?$query');
    try {
      final r = await http.get(uri, headers: AppConfig.apiHeaders).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final resultsList = data['results'] as List;
        
        final futures = resultsList.map((e) => getExerciseById(e['id']));
        final detailedList = await Future.wait(futures);
        return detailedList.whereType<MuscleWikiExercise>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<String>> getApiMuscles() async {
    final uri = Uri.parse('$_baseUrl/muscles');
    try {
      final r = await http.get(uri, headers: AppConfig.apiHeaders).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as List;
        return data.map((e) => e['name'].toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<String>> getApiCategories() async {
    final uri = Uri.parse('$_baseUrl/categories');
    try {
      final r = await http.get(uri, headers: AppConfig.apiHeaders).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as List;
        return data.map((e) => e['display_name'].toString()).toList();
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
