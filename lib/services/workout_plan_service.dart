import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_plan.dart';

class WorkoutPlanService {
  static const String _key = 'workout_plans';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<WorkoutPlan>> getPlans() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return WorkoutPlan.decodeList(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> savePlan(WorkoutPlan plan) async {
    final plans = await getPlans();
    final idx = plans.indexWhere((p) => p.id == plan.id);
    if (idx >= 0) {
      plans[idx] = plan;
    } else {
      plans.insert(0, plan);
    }
    await _persist(plans);
  }

  Future<void> deletePlan(String planId) async {
    final plans = await getPlans();
    plans.removeWhere((p) => p.id == planId);
    await _persist(plans);
  }

  Future<void> _persist(List<WorkoutPlan> plans) async {
    final prefs = await _prefs;
    await prefs.setString(_key, WorkoutPlan.encodeList(plans));
  }
}
