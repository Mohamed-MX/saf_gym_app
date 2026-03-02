import 'package:flutter/foundation.dart';
import '../services/muscle_wiki_service.dart';

class CategoryExercisesViewModel extends ChangeNotifier {
  final MuscleWikiService _service = MuscleWikiService();

  List<MuscleWikiExercise> _exercises = [];
  bool _isLoading = true;
  String? _error;

  List<MuscleWikiExercise> get exercises => _exercises;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadExercises(String muscleSlug) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _exercises = await _service.getExercisesByMuscle(
        muscle: muscleSlug,
        limit: 20,
      );
    } catch (_) {
      _error = 'Failed to load exercises';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
