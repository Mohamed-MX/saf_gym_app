import 'package:flutter/foundation.dart';
import '../models/workout_plan.dart';
import '../services/workout_plan_service.dart';

class WorkoutPlanEditorViewModel extends ChangeNotifier {
  final WorkoutPlanService _service = WorkoutPlanService();

  // ── Plan info ───────────────────────────────────────────────────────────
  String planName = '';
  final Set<String> _selectedDays = {};

  // ── Per-day exercises ───────────────────────────────────────────────────
  final Map<String, List<PlannedExercise>> _dayExercises = {};

  bool _isSaving = false;
  String? _error;

  // ── Constants ───────────────────────────────────────────────────────────
  static const List<String> weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  // ── Getters ─────────────────────────────────────────────────────────────
  Set<String> get selectedDays => Set.unmodifiable(_selectedDays);
  bool get isSaving => _isSaving;
  String? get error => _error;

  List<PlannedExercise> exercisesForDay(String day) =>
      _dayExercises[day] ?? [];

  bool get isValid =>
      planName.trim().isNotEmpty && _selectedDays.isNotEmpty;

  int get totalExerciseCount =>
      _dayExercises.values.fold(0, (s, list) => s + list.length);

  void setPlanName(String value) {
    planName = value;
    notifyListeners();
  }


  // ── Load existing plan for editing ──────────────────────────────────────
  void loadPlan(WorkoutPlan plan) {
    planName = plan.name;
    _selectedDays.clear();
    _dayExercises.clear();
    for (final day in plan.days) {
      _selectedDays.add(day.dayName);
      _dayExercises[day.dayName] = List.from(day.exercises);
    }
    notifyListeners();
  }

  // ── Day selection ────────────────────────────────────────────────────────
  void toggleDay(String day) {
    if (_selectedDays.contains(day)) {
      _selectedDays.remove(day);
      _dayExercises.remove(day);
    } else {
      _selectedDays.add(day);
      _dayExercises.putIfAbsent(day, () => []);
    }
    notifyListeners();
  }

  // ── Exercise management ──────────────────────────────────────────────────
  void addExercisesToDay(String day, List<PlannedExercise> exercises) {
    _dayExercises.putIfAbsent(day, () => []);
    for (final ex in exercises) {
      final alreadyAdded =
          _dayExercises[day]!.any((e) => e.exerciseId == ex.exerciseId);
      if (!alreadyAdded) {
        _dayExercises[day]!.add(ex);
      }
    }
    notifyListeners();
  }

  void removeExerciseFromDay(String day, int index) {
    _dayExercises[day]?.removeAt(index);
    notifyListeners();
  }

  void updateSets(String day, int index, int sets) {
    _dayExercises[day]?[index].sets = sets;
    notifyListeners();
  }

  void updateReps(String day, int index, int reps) {
    _dayExercises[day]?[index].reps = reps;
    notifyListeners();
  }

  void reorderExercise(String day, int oldIndex, int newIndex) {
    final list = _dayExercises[day];
    if (list == null) return;
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    notifyListeners();
  }

  // ── Save ─────────────────────────────────────────────────────────────────
  Future<WorkoutPlan?> savePlan({String? existingId}) async {
    if (!isValid) {
      _error = 'Please enter a plan name and select at least one day.';
      notifyListeners();
      return null;
    }
    _isSaving = true;
    _error = null;
    notifyListeners();

    final days = _selectedDays
        .where((d) => weekDays.contains(d))
        .toList()
      ..sort((a, b) =>
          weekDays.indexOf(a).compareTo(weekDays.indexOf(b)));

    final plan = WorkoutPlan(
      id: existingId ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: planName.trim(),
      days: days
          .map((d) => WorkoutDay(
                dayName: d,
                exercises: List.from(_dayExercises[d] ?? []),
              ))
          .toList(),
    );

    await _service.savePlan(plan);
    _isSaving = false;
    notifyListeners();
    return plan;
  }
}
