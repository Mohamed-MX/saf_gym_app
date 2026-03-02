import 'dart:convert';

// ── PlannedExercise ────────────────────────────────────────────────────────

class PlannedExercise {
  final int exerciseId;
  final String name;
  final String? thumbnailUrl;
  final String? muscleGroup;
  int sets;
  int reps;

  PlannedExercise({
    required this.exerciseId,
    required this.name,
    this.thumbnailUrl,
    this.muscleGroup,
    this.sets = 3,
    this.reps = 12,
  });

  factory PlannedExercise.fromJson(Map<String, dynamic> json) =>
      PlannedExercise(
        exerciseId: json['exerciseId'] as int,
        name: json['name'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        muscleGroup: json['muscleGroup'] as String?,
        sets: json['sets'] as int? ?? 3,
        reps: json['reps'] as int? ?? 12,
      );

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (muscleGroup != null) 'muscleGroup': muscleGroup,
        'sets': sets,
        'reps': reps,
      };
}

// ── WorkoutDay ─────────────────────────────────────────────────────────────

class WorkoutDay {
  final String dayName; // "Monday" … "Sunday"
  final List<PlannedExercise> exercises;

  WorkoutDay({required this.dayName, List<PlannedExercise>? exercises})
      : exercises = exercises ?? [];

  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
        dayName: json['dayName'] as String,
        exercises: (json['exercises'] as List<dynamic>?)
                ?.map((e) =>
                    PlannedExercise.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'dayName': dayName,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  WorkoutDay copyWith({List<PlannedExercise>? exercises}) =>
      WorkoutDay(dayName: dayName, exercises: exercises ?? this.exercises);
}

// ── WorkoutPlan ────────────────────────────────────────────────────────────

class WorkoutPlan {
  final String id;
  String name;
  final List<WorkoutDay> days;
  final DateTime createdAt;

  WorkoutPlan({
    required this.id,
    required this.name,
    required this.days,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalExercises =>
      days.fold(0, (sum, d) => sum + d.exercises.length);

  String get daysLabel => days.map((d) => d.dayName.substring(0, 3)).join(' · ');

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) => WorkoutPlan(
        id: json['id'] as String,
        name: json['name'] as String,
        days: (json['days'] as List<dynamic>?)
                ?.map((d) => WorkoutDay.fromJson(d as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'days': days.map((d) => d.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  static String encodeList(List<WorkoutPlan> plans) =>
      jsonEncode(plans.map((p) => p.toJson()).toList());

  static List<WorkoutPlan> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => WorkoutPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
