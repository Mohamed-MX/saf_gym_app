// ── saf_ai_model_exp.dart ─────────────────────────────────────────────────────
//
// Dart AI engine — mirrors the Python training logic in saf_ai_model_exp.py
// and the updated Colab notebook (10-feature model).
//
// Responsibilities
// ─────────────────
// • Muscle-group split  → deterministic table (guaranteed unique per day).
// • Sets, Reps, ExerciseCount, Cardio → driven by the AI model.
// • Equipment           → passed as multi-hot to the AI; rotated per day
//                         for the exercise fetch pool.
// • Weight-loss goal    → AI returns exerciseCount=6 + cardio="Treadmill".
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import '../models/workout_plan.dart';
import '../services/muscle_wiki_service.dart';
import '../services/ai_engine_service.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum AiExperienceLevel { beginner, intermediate, advanced }

enum AiTrainingGoal {
  hypertrophy('hypertrophy'),
  strength('strength'),
  weightLoss('weight_loss');

  final String modelName;
  const AiTrainingGoal(this.modelName);
}

// ── Equipment → free-exercise-db category ─────────────────────────────────────

const Map<String, String> _equipmentToCategory = {
  'Barbell'    : 'Barbell',
  'Dumbbells'  : 'Dumbbell',
  'Machines'   : 'Machine',
  'Cables'     : 'Cable',
  'Bodyweight' : 'Body Only',
  'Kettlebells': 'Kettlebells',
};

// ── Deterministic muscle-group split table ────────────────────────────────────
//
// Mirrors split_patterns from the Colab notebook exactly.
// Guarantees Push/Pull/Legs are always distinct — independent of model output.

const List<List<List<String>>> _splitTable = [
  // 1 day — Full Body
  [
    ['Chest', 'Quads', 'Lats', 'Front Shoulders', 'Hamstrings'],
  ],
  // 2 days — Upper / Lower
  [
    ['Chest', 'Lats', 'Biceps', 'Triceps', 'Front Shoulders'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
  ],
  // 3 days — Push / Pull / Legs
  [
    ['Chest', 'Triceps', 'Front Shoulders'],
    ['Lats', 'Biceps', 'Traps'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
  ],
  // 4 days — Push / Pull / Legs / Upper
  [
    ['Chest', 'Triceps', 'Front Shoulders'],
    ['Lats', 'Biceps', 'Traps'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
    ['Chest', 'Lats', 'Front Shoulders', 'Biceps'],
  ],
  // 5 days — Push / Pull / Legs / Upper / Lower
  [
    ['Chest', 'Triceps', 'Front Shoulders'],
    ['Lats', 'Biceps', 'Traps'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
    ['Chest', 'Lats', 'Front Shoulders', 'Biceps'],
    ['Quads', 'Hamstrings', 'Calves'],
  ],
  // 6 days — Push / Pull / Legs × 2
  [
    ['Chest', 'Triceps', 'Front Shoulders'],
    ['Lats', 'Biceps', 'Traps'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
    ['Chest', 'Triceps', 'Front Shoulders'],
    ['Lats', 'Biceps', 'Traps'],
    ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
  ],
  // 7 days
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

List<String> _musclesForDay(int dayCount, int dayIndex) =>
    _splitTable[dayCount.clamp(1, 7) - 1][dayIndex];

// ── Day-name helpers ──────────────────────────────────────────────────────────

const Map<String, String> _dayAbbrevToFull = {
  'Sun': 'Sunday',  'Mon': 'Monday', 'Tue': 'Tuesday', 'Wen': 'Wednesday',
  'Thu': 'Thursday','Fri': 'Friday', 'Sat': 'Saturday',
};

const List<String> _weekOrder = ['Sun','Mon','Tue','Wen','Thu','Fri','Sat'];

// ── SafAiModelExp ─────────────────────────────────────────────────────────────

class SafAiModelExp {
  SafAiModelExp._();

  static final MuscleWikiService _service = MuscleWikiService();
  static final Random _rng = Random(42);

  static Future<WorkoutPlan> generateWorkout({
    required AiExperienceLevel level,
    required AiTrainingGoal goal,
    required Set<String> equipment,
    required Set<String> selectedDays,
    int exercisesPerDay = 5,  // overridden by AI's exerciseCount per day
  }) async {
    // ── 1. Sort days ──────────────────────────────────────────────────────────
    final orderedDays = _weekOrder
        .where((d) => selectedDays.contains(d))
        .toList();
    final int dayCount = orderedDays.length;

    // ── 2. Resolve equipment fetch categories ─────────────────────────────────
    final List<String> categories = equipment
        .map((e) => _equipmentToCategory[e])
        .whereType<String>()
        .toList();
    final List<String> effectiveCategories =
        categories.isEmpty ? ['Body Only'] : categories;

    // ── 3. Fetch exercise pools per category (max 80 each) ────────────────────
    final Map<String, List<MuscleWikiExercise>> poolByCategory = {};
    for (final cat in effectiveCategories) {
      poolByCategory[cat] = await _service.getExercisesFiltered(
        category: cat,
        limit: 80,
      );
    }

    // ── 4. Initialise AI ──────────────────────────────────────────────────────
    await AiEngineService.instance.init();

    // ── 5. Build workout days ─────────────────────────────────────────────────
    final List<WorkoutDay> workoutDays = [];

    for (int i = 0; i < dayCount; i++) {
      final dayAbbrev = orderedDays[i];
      final fullDay   = _dayAbbrevToFull[dayAbbrev] ?? dayAbbrev;

      // ── 5a. Deterministic muscle split ─────────────────────────────────────
      final List<String> dayMuscles = _musclesForDay(dayCount, i);

      // ── 5b. Equipment rotation for the fetch pool ─────────────────────────
      final String dayCategory =
          effectiveCategories[i % effectiveCategories.length];

      // ── 5c. Ask AI (full equipment set → multi-hot encoding inside engine) ─
      final AiDayTarget aiDecision =
          await AiEngineService.instance.predictDayTarget(
        levelName  : level.name,
        goalName   : goal.modelName,
        daysPerWeek: dayCount,
        dayIndex   : i + 1,
        uiEquipment: equipment,         // ← full set, not just one item
      );

      // ── 5d. Filter exercises: category pool × day muscles ──────────────────
      List<MuscleWikiExercise> pool = List<MuscleWikiExercise>.from(
        poolByCategory[dayCategory] ?? [],
      );

      final muscleFiltered = pool
          .where((ex) =>
              ex.primaryMuscles.any((m) => dayMuscles.contains(m)))
          .toList();
      if (muscleFiltered.isNotEmpty) pool = muscleFiltered;

      // Deduplicate by name
      final seen = <String>{};
      pool = pool.where((ex) => seen.add(ex.name)).toList();

      // Shuffle deterministically
      pool.shuffle(Random(_rng.nextInt(10000) + i));

      // Use AI's exerciseCount (6 for weight_loss, 5 otherwise)
      final int pickCount = aiDecision.exerciseCount;
      final picked = pool.take(pickCount).toList();

      final plannedExercises = picked.map((ex) => PlannedExercise(
        exerciseId  : ex.id,
        name        : ex.name,
        thumbnailUrl: ex.displayImageUrl,
        muscleGroup : ex.muscleSlug ?? ex.primaryMusclesLabel,
        sets        : aiDecision.sets,
        reps        : aiDecision.reps,
      )).toList();

      // ── 5e. Cardio block — inserted FIRST when AI says so ─────────────────
      if (aiDecision.hasCardio) {
        final cardioName = '${aiDecision.cardio} Cardio';
        // The training data uses 6 as the cardio duration in the exercise_count
        // column; treat that same number as minutes for the cardio block.
        const int cardioMins = 6;
        plannedExercises.insert(0, PlannedExercise(
          exerciseId  : -1 * (i + 1),
          name        : cardioName,
          thumbnailUrl: null,
          muscleGroup : 'Cardio · $cardioMins min',
          sets        : 1,
          reps        : cardioMins,
        ));
      }

      workoutDays.add(WorkoutDay(dayName: fullDay, exercises: plannedExercises));
    }

    // ── 6. Plan name ──────────────────────────────────────────────────────────
    final levelLabel = level.name[0].toUpperCase() + level.name.substring(1);
    final goalLabel  = goal == AiTrainingGoal.weightLoss ? 'Fat Loss'
                     : goal == AiTrainingGoal.strength   ? 'Strength'
                     : 'Hypertrophy';

    return WorkoutPlan(
      id       : 'ai_${DateTime.now().millisecondsSinceEpoch}',
      name     : 'AI Plan · $levelLabel · $goalLabel · ${dayCount}d',
      days     : workoutDays,
      createdAt: DateTime.now(),
    );
  }
}