import 'package:flutter/foundation.dart';
import '../services/muscle_wiki_service.dart';

class HomeViewModel extends ChangeNotifier {
  final MuscleWikiService _service = MuscleWikiService();

  List<MuscleWikiExercise> _exercises = [];
  bool _isLoading = true;
  String? _error;
  late DateTime _today;

  HomeViewModel() {
    _today = DateTime.now();
    Future.microtask(loadWorkout);
  }

  List<MuscleWikiExercise> get exercises => _exercises;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get today => _today;

  String get formattedDate {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[_today.month - 1]} ${_today.day}, ${_today.year}';
  }

  Future<void> loadWorkout() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _exercises =
          await _service.getDailyWorkoutExercises(date: _today);
      if (_exercises.isEmpty) {
        _error = 'No exercises found. Please check your connection.';
      }
    } catch (_) {
      _error = 'Failed to load workout. Please check your connection.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
