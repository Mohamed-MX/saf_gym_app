import 'dart:math';

/// Generates a deterministic daily workout by selecting exercises
/// from different categories using the current date as a seed.
class WorkoutGenerator {
  // Curated list of exercise IDs that are known to have good
  // English translations and images in the wger database
  static const List<int> _curatedExerciseIds = [
    // Abs
    91, 94, 416, 567,
    // Arms (Biceps/Triceps)
    81, 74, 86, 83, 274, 82, 129,
    // Back
    109, 110, 108, 342, 106, 113,
    // Calves
    104, 776,
    // Cardio
    810,
    // Chest
    192, 97, 100, 99, 101,
    // Legs (Quads/Glutes/Hamstrings)
    111, 105, 112, 64, 191, 404,
    // Shoulders
    119, 123, 148, 152, 227,
  ];

  // Map category IDs to exercise IDs for balanced selection
  static const Map<int, List<int>> _categoryExercises = {
    10: [91, 94, 416, 567],             // Abs
    8: [81, 74, 86, 83, 274, 82, 129],  // Arms
    12: [109, 110, 108, 342, 106, 113], // Back
    14: [104, 776],                      // Calves
    15: [810],                           // Cardio
    11: [192, 97, 100, 99, 101],        // Chest
    9: [111, 105, 112, 64, 191, 404],   // Legs
    13: [119, 123, 148, 152, 227],      // Shoulders
  };

  /// Generates a list of exercise IDs for today's Workout of the Day.
  /// Uses the current date as a seed so the same workout is shown all day.
  /// Picks 6 exercises across different muscle groups for a balanced workout.
  List<int> generateDailyWorkout({DateTime? date}) {
    final today = date ?? DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final random = Random(seed);

    final selectedIds = <int>[];
    
    // Pick categories to include (always aim for variety)
    final categoryIds = _categoryExercises.keys.toList();
    categoryIds.shuffle(random);

    // Select 6 exercises from different categories
    final targetCount = 6;
    int categoryIndex = 0;

    while (selectedIds.length < targetCount &&
        categoryIndex < categoryIds.length) {
      final catId = categoryIds[categoryIndex];
      final exercises = _categoryExercises[catId]!;
      final exerciseIndex = random.nextInt(exercises.length);
      final selectedId = exercises[exerciseIndex];

      if (!selectedIds.contains(selectedId)) {
        selectedIds.add(selectedId);
      }
      categoryIndex++;
    }

    // If still need more, pick randomly from full list
    while (selectedIds.length < targetCount) {
      final id =
          _curatedExerciseIds[random.nextInt(_curatedExerciseIds.length)];
      if (!selectedIds.contains(id)) {
        selectedIds.add(id);
      }
    }

    return selectedIds;
  }

  /// Get the day name for display
  static String getDayLabel(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday - 1];
  }

  /// Get a motivational focus label based on the day
  static String getDayFocus(DateTime date) {
    const focuses = [
      'Push Day 💪',         // Monday
      'Pull Day 🏋️',        // Tuesday
      'Leg Day 🦵',          // Wednesday
      'Upper Body 💥',       // Thursday
      'Full Body 🔥',        // Friday
      'Core & Cardio 🫀',   // Saturday
      'Active Recovery 🧘', // Sunday
    ];
    return focuses[date.weekday - 1];
  }
}
