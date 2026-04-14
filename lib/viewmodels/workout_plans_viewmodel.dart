import 'package:flutter/foundation.dart';
import '../models/workout_plan.dart';
import '../services/saf_database.dart';

class WorkoutPlansViewModel extends ChangeNotifier {
  final SafDatabase _service = SafDatabase.instance;

  List<WorkoutPlan> _plans = [];
  bool _isLoading = true;

  List<WorkoutPlan> get plans => _plans;
  bool get isLoading => _isLoading;

  WorkoutPlansViewModel() {
    Future.microtask(loadPlans);
  }

  Future<void> loadPlans() async {
    _isLoading = true;
    notifyListeners();
    _plans = await _service.getPlans();

    // ── MOCK: fill any empty Tuesday day with demo exercises ──────────────
    // Remove once API key is renewed and real exercises are added.
    final mockExercises = [
      PlannedExercise(
        exerciseId: 0,
        name: 'Bicep Curl',
        muscleGroup: 'Biceps',
        sets: 3,
        reps: 12,
      ),
      PlannedExercise(
        exerciseId: 1,
        name: 'Hammer Curl',
        muscleGroup: 'Biceps',
        sets: 3,
        reps: 10,
      ),
    ];
    _plans = _plans.map((plan) {
      final patchedDays = plan.days.map((day) {
        if (day.dayName == 'Tuesday' && day.exercises.isEmpty) {
          return day.copyWith(exercises: mockExercises);
        }
        return day;
      }).toList();
      return WorkoutPlan(
        id: plan.id,
        name: plan.name,
        days: patchedDays,
        createdAt: plan.createdAt,
      );
    }).toList();
    // ─────────────────────────────────────────────────────────────────────

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deletePlan(String planId) async {
    await _service.deletePlan(planId);
    _plans.removeWhere((p) => p.id == planId);
    notifyListeners();
  }
}
