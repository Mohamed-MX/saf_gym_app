import 'package:flutter/foundation.dart';
import '../models/workout_plan.dart';
import '../services/saf_database.dart';
import '../services/muscle_wiki_service.dart';

class WorkoutPlanEditorViewModel extends ChangeNotifier {
  final SafDatabase _service = SafDatabase.instance;
  final MuscleWikiService _apiService = MuscleWikiService();

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
    if (sets < 1) return;
    _dayExercises[day]?[index].updateSets(sets);
    notifyListeners();
  }

  void updateWeight(String day, int index, int setIndex, double newWeight) {
    if (newWeight < 0) return;
    _dayExercises[day]?[index].weights[setIndex] = newWeight;
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

    // Cache exercises for offline use before saving the plan metadata
    await _cachePlanExercises(plan);

    await _service.savePlan(plan);
    _isSaving = false;
    notifyListeners();
    return plan;
  }

  // ── Offline Caching ──────────────────────────────────────────────────────
  Future<void> _cachePlanExercises(WorkoutPlan plan) async {
    final uniqueIds = <int>{};
    for (final day in plan.days) {
      for (final ex in day.exercises) {
        uniqueIds.add(ex.exerciseId);
      }
    }

    // Try fetching each exercise
    final futures = uniqueIds.map((id) async {
      // 1. Check if it's already in the cache
      final cached = await _service.getExercise(id);
      if (cached != null) return; // Already saved locally

      // 2. If it's not, fetch the full definition from the API
      final fullExercise = await _apiService.getExerciseById(id);
      if (fullExercise != null) {
        // 3. Save it to the cache so the detail screen can load it offline
        await _service.upsertExercise(fullExercise);
      }
    });

    await Future.wait(futures);
  }
}
