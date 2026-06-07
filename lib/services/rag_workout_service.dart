// ── rag_workout_service.dart ──────────────────────────────────────────────────
//
// Calls the FastAPI backend to generate a full weekly workout plan using the
// RAG pipeline (similarity search + LLM). This is the PRIMARY plan generator.
//
// ⚠️  TO CHANGE THE SERVER URL:
//     Update `VERCEL_URL` via flutter_dotenv in your .env file.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/workout_plan.dart';

// ════════════════════════════════════════════════════════════════════════════
// ⚠️  SERVER URL — reading from .env with fallback
// ════════════════════════════════════════════════════════════════════════════
final String _baseUrl = dotenv.env['VERCEL_URL'] ?? 'https://saf-gym-app-backend.vercel.app';

// Goal mapping: app labels → dataset labels
const Map<String, String> _goalToDataset = {
  'hypertrophy': 'gain_muscle',
  'strength':    'strength',
  'weight_loss': 'lose_weight',
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

  /// Pings the backend health endpoint to "warm up" the Vercel serverless function.
  /// This prevents the 5-10 second cold start delay when the user clicks generate.
  Future<void> warmUpBackend() async {
    try {
      // ignore: avoid_print
      print('🔥 Warming up AI backend...');
      await http.get(Uri.parse('$_baseUrl/health')).timeout(const Duration(seconds: 15));
      // ignore: avoid_print
      print('✅ AI backend is warm and ready');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Failed to warm up AI backend: $e');
    }
  }

  // ── Primary: call the FastAPI RAG backend ──────────────────────────────────

  /// Generate a full weekly workout plan via the FastAPI backend.
  /// Returns null if the server is unreachable.
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
      } else if (response.statusCode == 504) {
        // ignore: avoid_print
        print('❌ FastAPI timeout (504)');
        throw Exception('Vercel Timeout (504). Please ensure you redeployed the backend with maxDuration: 60 in vercel.json!');
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
        String? parseString(dynamic value) {
          if (value == null) return null;
          if (value is List) return value.map((e) => e.toString()).join(', ');
          return value.toString();
        }

        final exerciseName = parseString(ex['exercise']) ?? 'Exercise';

        return PlannedExercise(
          exerciseId  : exerciseName.hashCode.abs(),  // synthetic ID
          name        : exerciseName,
          thumbnailUrl: null,   // RAG plan doesn't include images
          muscleGroup : parseString(ex['target_muscle']),
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

/// Generates a workout plan using the FastAPI RAG backend.
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

  throw Exception('Failed to generate workout from API. Please check your connection to the Vercel backend.');
}
