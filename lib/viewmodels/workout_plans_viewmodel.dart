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
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deletePlan(String planId) async {
    await _service.deletePlan(planId);
    _plans.removeWhere((p) => p.id == planId);
    notifyListeners();
  }
}
