import 'dart:math';
import '../models/workout_plan.dart';
import '../services/muscle_wiki_service.dart';
import '../services/ai_engine_service.dart'; // <-- Import the new service

enum AiExperienceLevel { beginner, intermediate, advanced }

const Map<String, String> _equipmentToCategory = {
  'Barbell': 'Barbell',
  'Dumbbells': 'Dumbbell',
  'Machines': 'Machine',
  'Cables': 'Cable',
  'Bodyweight': 'Body Only',
  'Kettlebells': 'Kettlebells',
};

const Map<String, String> _dayAbbrevToFull = {
  'Sun': 'Sunday', 'Mon': 'Monday', 'Tue': 'Tuesday', 'Wen': 'Wednesday',
  'Thu': 'Thursday', 'Fri': 'Friday', 'Sat': 'Saturday',
};

const List<String> _weekOrder = ['Sun', 'Mon', 'Tue', 'Wen', 'Thu', 'Fri', 'Sat'];

class SafAiModelExp {
  SafAiModelExp._();

  static final MuscleWikiService _service = MuscleWikiService();
  static final Random _rng = Random(42);

  static Future<WorkoutPlan> generateWorkout({
    required AiExperienceLevel level,
    required Set<String> equipment,
    required Set<String> selectedDays,
    int exercisesPerDay = 5,
  }) async {

    // Sort selected days by calendar order
    final orderedDays = _weekOrder.where((d) => selectedDays.contains(d)).toList();
    final int dayCount = orderedDays.length;

    // Derive category filters
    final List<String> categories = equipment
        .map((e) => _equipmentToCategory[e])
        .whereType<String>()
        .toList();

    // Fetch exercises from API
    final Map<String, List<MuscleWikiExercise>> exercisesByCategory = {};
    for (final cat in categories.isEmpty ? ['Body Only'] : categories) {
      exercisesByCategory[cat] = await _service.getExercisesFiltered(
        category: cat, limit: 80,
      );
    }

    final List<MuscleWikiExercise> allExercises = exercisesByCategory.values
        .expand((list) => list).toList();

    final List<WorkoutDay> workoutDays = [];

    // --- AI INTEGRATION HAPPENS HERE ---
    // Make sure AI is ready
    await AiEngineService.instance.init();

    // We pass the first piece of equipment to the AI to help it decide the split
    String primaryEquipment = equipment.isNotEmpty ? equipment.first : "Bodyweight";

    for (int i = 0; i < dayCount; i++) {
      final dayAbbrev = orderedDays[i];
      final fullDay = _dayAbbrevToFull[dayAbbrev] ?? dayAbbrev;

      // 🧠 ASK THE AI: "What should the user do today?"
      final aiDecision = await AiEngineService.instance.predictDayTarget(
        levelName: level.name,
        daysPerWeek: dayCount,
        dayIndex: i + 1, // 1-indexed
        equipment: primaryEquipment,
      );

      List<String> aiMuscles = aiDecision['muscles'];
      int aiSets = aiDecision['sets'];
      int aiReps = aiDecision['reps'];

      // Filter exercises by the muscles the AI selected
      List<MuscleWikiExercise> pool = allExercises
          .where((ex) => ex.primaryMuscles.any((m) => aiMuscles.contains(m)))
          .toList();

      if (pool.isEmpty) pool = List.from(allExercises);

      final seen = <String>{};
      pool = pool.where((ex) => seen.add(ex.name)).toList();

      final daySeed = _rng.nextInt(10000) + i;
      pool.shuffle(Random(daySeed));

      final picked = pool.take(exercisesPerDay).toList();

      // Apply the Sets and Reps the AI decided
      final plannedExercises = picked.map((ex) => PlannedExercise(
        exerciseId: ex.id,
        name: ex.name,
        thumbnailUrl: ex.displayImageUrl,
        muscleGroup: ex.muscleSlug ?? ex.primaryMusclesLabel,
        sets: aiSets,
        reps: aiReps,
      )).toList();

      workoutDays.add(WorkoutDay(dayName: fullDay, exercises: plannedExercises));
    }

    final levelName = level.name[0].toUpperCase() + level.name.substring(1);

    return WorkoutPlan(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      name: 'AI Plan · $levelName · ${dayCount}d',
      days: workoutDays,
      createdAt: DateTime.now(),
    );
  }
}