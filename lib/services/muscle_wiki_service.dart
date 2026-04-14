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
    if (e.containsKey('primary_muscles')) {
      // Legacy parse
      return MuscleWikiExercise(
        id: e['id'] ?? 0,
        name: e['name'] ?? 'Unknown',
        primaryMuscles: List<String>.from(e['primary_muscles'] ?? []),
        category: e['category'] as String?,
        difficulty: e['difficulty'] as String?,
        steps: List<String>.from(e['steps'] ?? []),
        thumbnailUrl: e['og_image'],
        gifUrl: e['url'],
        muscleSlug: e['_muscleSlug'],
        videos: [],
      );
    }
    
    // Yuhonas DB mapping
    String? thumb;
    if (e['images'] != null && (e['images'] as List).isNotEmpty) {
      thumb = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/${e['images'][0]}';
    }
    
    final rawMuscles = List<String>.from(e['primaryMuscles'] ?? []);
    final mappedMuscles = rawMuscles.map((m) {
      if (m == 'abdominals') return 'Abdominals';
      if (m == 'chest') return 'Chest';
      if (m == 'shoulders') return 'Front Shoulders';
      if (m == 'biceps') return 'Biceps';
      if (m == 'forearms') return 'Forearms';
      if (m == 'quadriceps' || m == 'adductors') return 'Quads';
      if (m == 'calves') return 'Calves';
      if (m == 'trapezius') return 'Traps';
      if (m == 'lats' || m == 'middle back') return 'Lats';
      if (m == 'triceps') return 'Triceps';
      if (m == 'hamstrings') return 'Hamstrings';
      if (m == 'glutes' || m == 'abductors') return 'Glutes';
      if (m == 'lower back') return 'Lower Back';
      return '${m[0].toUpperCase()}${m.substring(1)}';
    }).toList();

    String cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

    return MuscleWikiExercise(
      id: e['id'].hashCode.abs() % 100000,
      name: e['name'] ?? 'Unknown',
      primaryMuscles: mappedMuscles,
      category: e['equipment'] != null ? cap(e['equipment']) : 'Body Only',
      difficulty: e['level'] != null ? cap(e['level']) : 'Beginner',
      steps: List<String>.from(e['instructions'] ?? []),
      thumbnailUrl: thumb,
      gifUrl: thumb,
      muscleSlug: mappedMuscles.isNotEmpty ? mappedMuscles.first : null,
      videos: [],
    );
  }
}

// ── MuscleWikiService ──────────────────────────────────────────────────────

class MuscleWikiService {
  static const String _dbUrl = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json';

  static List<Map<String, dynamic>>? _cachedData;

  Future<List<Map<String, dynamic>>> _fetchData() async {
    if (_cachedData != null) return _cachedData!;
    try {
      final r = await http.get(Uri.parse(_dbUrl)).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        _cachedData = List<Map<String, dynamic>>.from(jsonDecode(r.body));
        return _cachedData!;
      }
    } catch (_) {}
    return [];
  }

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

  static const List<String> _workoutMuscles = [
    'Chest', 'Lats', 'Biceps', 'Triceps',
    'Front Shoulders', 'Abdominals', 'Quads',
    'Hamstrings', 'Glutes', 'Calves', 'Traps',
  ];

  // ── Public API ──────────────────────────────────────────────────────────

  List<MuscleCategory> getMuscleCategories() => _allCategories;

  Future<List<MuscleWikiExercise>> getExercisesByMuscle({
    required String muscle,
    int limit = 20,
  }) async {
    final apiMuscle = muscleSlugMap[muscle] ?? muscle;
    final allData = await _fetchData();
    var results = allData.map((e) => MuscleWikiExercise._mapper(e))
        .where((e) => e.primaryMuscles.contains(apiMuscle))
        .toList();
    if (results.length > limit) results = results.sublist(0, limit);
    return results.map((e) => e.withSlug(muscle)).toList();
  }

  Future<MuscleWikiExercise?> getExerciseById(
    int id, {
    String? muscleSlug,
  }) async {
    final allData = await _fetchData();
    try {
      final mapped = allData.map((e) => MuscleWikiExercise._mapper(e));
      final ex = mapped.firstWhere((e) => e.id == id);
      return muscleSlug != null ? ex.withSlug(muscleSlug) : ex;
    } catch (_) {
      return null;
    }
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
    String? muscle,
    String? category,
    String? difficulty,
    int limit = 20,
    int offset = 0,
  }) async {
    final allData = await _fetchData();
    var mapped = allData.map((e) => MuscleWikiExercise._mapper(e)).toList();

    if (muscle != null && muscle.isNotEmpty) {
      mapped = mapped.where((e) => e.primaryMuscles.contains(muscle)).toList();
    }
    if (category != null && category.isNotEmpty) {
      mapped = mapped.where((e) => e.category?.toLowerCase() == category.toLowerCase()).toList();
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      mapped = mapped.where((e) => e.difficulty?.toLowerCase() == difficulty.toLowerCase()).toList();
    }

    if (offset >= mapped.length) return [];
    var end = offset + limit;
    if (end > mapped.length) end = mapped.length;
    return mapped.sublist(offset, end);
  }

  Future<List<String>> getApiMuscles() async {
    final allData = await _fetchData();
    final muscles = <String>{};
    for (var e in allData) {
      final mEx = MuscleWikiExercise._mapper(e);
      muscles.addAll(mEx.primaryMuscles);
    }
    return muscles.toList()..sort();
  }

  Future<List<String>> getApiCategories() async {
    final allData = await _fetchData();
    final categories = <String>{};
    for (var e in allData) {
      final mEx = MuscleWikiExercise._mapper(e);
      if (mEx.category != null && mEx.category!.isNotEmpty && mEx.category != 'None') {
        categories.add(mEx.category!);
      }
    }
    return categories.toList()..sort();
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
