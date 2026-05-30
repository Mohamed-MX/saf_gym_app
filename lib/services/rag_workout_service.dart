// ── rag_workout_service.dart ──────────────────────────────────────────────────
//
// Calls the FastAPI backend to generate a full weekly workout plan using the
// RAG pipeline (similarity search + LLM). This is the PRIMARY plan generator.
//
// Fallback: if the API is unreachable, SafAiModelExp (TFLite) is used instead.
//
// ⚠️  TO CHANGE THE SERVER URL:
//     Update `_baseUrl` below OR set it via flutter_dotenv in your .env file.
//     - Local dev:    http://10.0.2.2:8000   (Android emulator → localhost)
//     - Real device:  http://YOUR_PC_IP:8000
//     - Cloud (prod): https://your-app.onrender.com
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/workout_plan.dart';
import 'ai_engine_service.dart';     // TFLite fallback
import 'muscle_wiki_service.dart';   // exercise data for TFLite fallback path

// ════════════════════════════════════════════════════════════════════════════
// ⚠️  SERVER URL — change this to your deployed Render/Railway URL
// ════════════════════════════════════════════════════════════════════════════
const String _baseUrl = 'https://your-app-name.onrender.com';
// const String _baseUrl = 'http://10.0.2.2:8000';   // ← use this for local testing

// Goal mapping: app labels → dataset labels
const Map<String, String> _goalToDataset = {
  'hypertrophy': 'gain_muscle',
  'strength':    'strength',
  'weight_loss': 'lose_weight',
};

// Equipment label mapping: app UI labels → dataset labels
const Map<String, String> _equipToDataset = {
  'Barbell':     'barbell',
  'Dumbbells':   'dumbbell',
  'Machines':    'machine',
  'Cables':      'cable',
  'Bodyweight':  'bodyweight',
  'Kettlebells': 'kettlebell',
};

const Map<String, String> _dayAbbrevToFull = {
  'Sun': 'Sunday',  'Mon': 'Monday',  'Tue': 'Tuesday',
  'Wen': 'Wednesday', 'Thu': 'Thursday', 'Fri': 'Friday', 'Sat': 'Saturday',
};

const List<String> _weekOrder = ['Sun', 'Mon', 'Tue', 'Wen', 'Thu', 'Fri', 'Sat'];

// ════════════════════════════════════════════════════════════════════════════
// RagWorkoutService
// ════════════════════════════════════════════════════════════════════════════

class RagWorkoutService {
  RagWorkoutService._();
  static final RagWorkoutService instance = RagWorkoutService._();

  // ── Primary: call the FastAPI RAG backend ──────────────────────────────────

  /// Generate a full weekly workout plan via the FastAPI backend.
  /// Returns null if the server is unreachable (use fallback then).
  Future<WorkoutPlan?> generateFromApi({
    required int age,
    required String gender,        // "male" | "female" | "other"
    required double heightCm,
    required double weightKg,
    required double bmi,
    required String goal,          // "hypertrophy" | "strength" | "weight_loss"
    required String experience,    // "beginner" | "intermediate" | "advanced"
    required Set<String> selectedDays,
    required Set<String> equipment,
    String injuries = 'none',
  }) async {
    // Sort days in week order
    final orderedDays = _weekOrder
        .where((d) => selectedDays.contains(d))
        .toList();
    final trainingDays = orderedDays.length;

    // Map goal to dataset label
    final datasetGoal = _goalToDataset[goal.toLowerCase()] ?? 'gain_muscle';

    final requestBody = {
      'age':           age,
      'gender':        gender.toLowerCase(),
      'height_cm':     heightCm,
      'weight_kg':     weightKg,
      'bmi':           bmi,
      'goal':          datasetGoal,
      'experience':    experience.toLowerCase(),
      'training_days': trainingDays,
      'injuries':      injuries.toLowerCase(),
    };

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/generate-plan'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _mapApiResponseToPlan(
          data: data,
          orderedDays: orderedDays,
          goal: goal,
          experience: experience,
        );
      } else {
        // ignore: avoid_print
        print('❌ FastAPI error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ FastAPI unreachable: $e');
      return null;
    }
  }

  // ── Map API response → WorkoutPlan ────────────────────────────────────────

  WorkoutPlan _mapApiResponseToPlan({
    required Map<String, dynamic> data,
    required List<String> orderedDays,
    required String goal,
    required String experience,
  }) {
    final weeklyProgram =
        data['weekly_program'] as Map<String, dynamic>? ?? {};

    // The API returns day keys like "day_1", "day_1_upper", etc.
    // We pair them in order with our selected days.
    final dayKeys = weeklyProgram.keys.toList();

    final List<WorkoutDay> workoutDays = [];

    for (int i = 0; i < orderedDays.length && i < dayKeys.length; i++) {
      final dayAbbrev = orderedDays[i];
      final fullDay   = _dayAbbrevToFull[dayAbbrev] ?? dayAbbrev;
      final dayKey    = dayKeys[i];

      final exerciseList =
          (weeklyProgram[dayKey] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();

      final planned = exerciseList.map((ex) {
        return PlannedExercise(
          exerciseId  : ex['exercise'].hashCode.abs(),  // synthetic ID
          name        : ex['exercise'] as String? ?? 'Exercise',
          thumbnailUrl: null,   // RAG plan doesn't include images
          muscleGroup : ex['target_muscle'] as String?,
          sets        : (ex['sets'] as num?)?.toInt() ?? 3,
          reps        : (ex['reps'] as num?)?.toInt() ?? 12,
        );
      }).toList();

      workoutDays.add(WorkoutDay(dayName: fullDay, exercises: planned));
    }

    final split      = data['workout_split'] as String? ?? 'custom';
    final levelLabel = _capitalize(experience);
    final goalLabel  = goal == 'weight_loss' ? 'Fat Loss'
                     : goal == 'strength'    ? 'Strength'
                     : 'Hypertrophy';

    return WorkoutPlan(
      id       : 'rag_${DateTime.now().millisecondsSinceEpoch}',
      name     : 'AI Plan · $levelLabel · $goalLabel · ${orderedDays.length}d',
      days     : workoutDays,
      createdAt: DateTime.now(),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ════════════════════════════════════════════════════════════════════════════
// RagWithFallback — top-level helper used by the UI
// ════════════════════════════════════════════════════════════════════════════

/// Generates a workout plan:
///   1. Tries the FastAPI RAG backend (primary)
///   2. Falls back to the local TFLite model (AiEngineService) if unreachable
Future<WorkoutPlan> generateWorkoutWithFallback({
  required int age,
  required String gender,
  required double heightCm,
  required double weightKg,
  required double bmi,
  required String goal,          // "hypertrophy" | "strength" | "weight_loss"
  required String experience,    // "beginner" | "intermediate" | "advanced"
  required Set<String> selectedDays,
  required Set<String> equipment,
  String injuries = 'none',
}) async {
  // ── 1. Try RAG backend ─────────────────────────────────────────────────────
  // ignore: avoid_print
  print('🚀 Trying RAG backend at $_baseUrl ...');
  final ragPlan = await RagWorkoutService.instance.generateFromApi(
    age          : age,
    gender       : gender,
    heightCm     : heightCm,
    weightKg     : weightKg,
    bmi          : bmi,
    goal         : goal,
    experience   : experience,
    selectedDays : selectedDays,
    equipment    : equipment,
    injuries     : injuries,
  );

  if (ragPlan != null) {
    // ignore: avoid_print
    print('✅ RAG plan received');
    return ragPlan;
  }

  // ── 2. Fallback: local TFLite model ────────────────────────────────────────
  // ignore: avoid_print
  print('⚠️ RAG unavailable — falling back to TFLite model');
  return _generateTfliteFallback(
    goal         : goal,
    experience   : experience,
    selectedDays : selectedDays,
    equipment    : equipment,
  );
}

// ── TFLite fallback (original AiEngineService + MuscleWiki pipeline) ─────────

const Map<String, String> _goalModelName = {
  'hypertrophy': 'hypertrophy',
  'strength':    'strength',
  'weight_loss': 'weight_loss',
};

const Map<String, String> _expModelName = {
  'beginner':     'beginner',
  'intermediate': 'intermediate',
  'advanced':     'advanced',
};

const List<List<List<String>>> _splitTable = [
  [['Chest', 'Quads', 'Lats', 'Front Shoulders', 'Hamstrings']],
  [
    ['Chest', 'Lats', 'Biceps', 'Triceps', 'Front Shoulders'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
  ],
  [
    ['Chest', 'Triceps', 'Front Shoulders'],
    ['Lats', 'Biceps', 'Traps'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
  ],
  [
    ['Chest', 'Triceps', 'Front Shoulders'],
    ['Lats', 'Biceps', 'Traps'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
    ['Chest', 'Lats', 'Front Shoulders', 'Biceps'],
  ],
  [
    ['Chest', 'Triceps', 'Front Shoulders'],
    ['Lats', 'Biceps', 'Traps'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
    ['Chest', 'Lats', 'Front Shoulders', 'Biceps'],
    ['Quads', 'Hamstrings', 'Calves'],
  ],
  [
    ['Chest', 'Triceps', 'Front Shoulders'],
    ['Lats', 'Biceps', 'Traps'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
    ['Chest', 'Triceps', 'Front Shoulders'],
    ['Lats', 'Biceps', 'Traps'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
  ],
  [
    ['Chest', 'Triceps', 'Front Shoulders'],
    ['Lats', 'Biceps', 'Traps'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
    ['Chest', 'Lats', 'Front Shoulders', 'Biceps'],
    ['Abdominals'],
    ['Chest', 'Triceps', 'Front Shoulders'],
    ['Lats', 'Biceps', 'Traps'],
  ],
];

const Map<String, String> _equipToCategory = {
  'Barbell':     'Barbell',
  'Dumbbells':   'Dumbbell',
  'Machines':    'Machine',
  'Cables':      'Cable',
  'Bodyweight':  'Body Only',
  'Kettlebells': 'Kettlebells',
};

Future<WorkoutPlan> _generateTfliteFallback({
  required String goal,
  required String experience,
  required Set<String> selectedDays,
  required Set<String> equipment,
}) async {
  final service     = MuscleWikiService();
  final rng         = Random(42);
  final orderedDays = _weekOrder
      .where((d) => selectedDays.contains(d))
      .toList();
  final dayCount    = orderedDays.length;

  final categories = equipment
      .map((e) => _equipToCategory[e])
      .whereType<String>()
      .toList();
  final effectiveCats = categories.isEmpty ? ['Body Only'] : categories;

  // Fetch exercise pools
  final Map<String, List<MuscleWikiExercise>> poolByCategory = {};
  for (final cat in effectiveCats) {
    poolByCategory[cat] =
        await service.getExercisesFiltered(category: cat, limit: 80);
  }

  await AiEngineService.instance.init();

  final List<WorkoutDay> workoutDays = [];

  for (int i = 0; i < dayCount; i++) {
    final dayAbbrev = orderedDays[i];
    final fullDay   = _dayAbbrevToFull[dayAbbrev] ?? dayAbbrev;
    final muscles   = _splitTable[dayCount.clamp(1, 7) - 1][i];
    final dayCategory = effectiveCats[i % effectiveCats.length];

    final aiDecision = await AiEngineService.instance.predictDayTarget(
      levelName  : _expModelName[experience.toLowerCase()] ?? 'intermediate',
      goalName   : _goalModelName[goal.toLowerCase()] ?? 'hypertrophy',
      daysPerWeek: dayCount,
      dayIndex   : i + 1,
      uiEquipment: equipment,
    );

    List<MuscleWikiExercise> pool =
        List.from(poolByCategory[dayCategory] ?? []);
    final filtered =
        pool.where((ex) => ex.primaryMuscles.any(muscles.contains)).toList();
    if (filtered.isNotEmpty) pool = filtered;

    final seen = <String>{};
    pool = pool.where((ex) => seen.add(ex.name)).toList();
    pool.shuffle(Random(rng.nextInt(10000) + i));

    final picked = pool.take(aiDecision.exerciseCount).toList();

    final planned = picked.map((ex) => PlannedExercise(
          exerciseId  : ex.id,
          name        : ex.name,
          thumbnailUrl: ex.displayImageUrl,
          muscleGroup : ex.muscleSlug ?? ex.primaryMusclesLabel,
          sets        : aiDecision.sets,
          reps        : aiDecision.reps,
        )).toList();

    if (aiDecision.hasCardio) {
      planned.insert(
        0,
        PlannedExercise(
          exerciseId  : -1 * (i + 1),
          name        : '${aiDecision.cardio} Cardio',
          thumbnailUrl: null,
          muscleGroup : 'Cardio · 6 min',
          sets        : 1,
          reps        : 6,
        ),
      );
    }

    workoutDays.add(WorkoutDay(dayName: fullDay, exercises: planned));
  }

  final levelLabel = experience[0].toUpperCase() + experience.substring(1);
  final goalLabel  = goal == 'weight_loss' ? 'Fat Loss'
                   : goal == 'strength'    ? 'Strength'
                   : 'Hypertrophy';

  return WorkoutPlan(
    id       : 'tflite_${DateTime.now().millisecondsSinceEpoch}',
    name     : 'AI Plan · $levelLabel · $goalLabel · ${dayCount}d',
    days     : workoutDays,
    createdAt: DateTime.now(),
  );
}
