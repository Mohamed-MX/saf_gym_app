import 'package:flutter/foundation.dart';
import '../services/muscle_wiki_service.dart';
import '../services/saf_database.dart';

class HomeViewModel extends ChangeNotifier {
  final MuscleWikiService _service = MuscleWikiService();

  List<MuscleWikiExercise> _exercises = [];
  bool _isLoading = true;
  String? _error;
  late DateTime _today;

  int _dayStreak = 0;
  int _totalReps = 0;
  int _totalMinutes = 0;

  int get dayStreak => _dayStreak;
  int get totalReps => _totalReps;
  int get totalMinutes => _totalMinutes;

  HomeViewModel() {
    _today = DateTime.now();
    Future.microtask(() async {
      await loadWorkout();
      await loadStats();
    });
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

  Future<void> loadStats() async {
    final db = SafDatabase.instance;
    final logs = await db.getPerformanceLogs();
    final plans = await db.getPlans();

    int reps = 0;
    int seconds = 0;
    Set<DateTime> workoutDates = {};

    for (var log in logs) {
      reps += (log['reps'] as int? ?? 0);
      seconds += (log['time_taken_seconds'] as int? ?? 0);
      
      final dt = DateTime.fromMillisecondsSinceEpoch(log['date_time']);
      workoutDates.add(DateTime(dt.year, dt.month, dt.day));
    }

    _totalReps = reps;
    _totalMinutes = seconds ~/ 60;

    Set<String> scheduledDays = {};
    for (final plan in plans) {
      for (final day in plan.days) {
        if (day.exercises.isNotEmpty) {
          scheduledDays.add(day.dayName);
        }
      }
    }

    int streak = 0;
    if (workoutDates.isNotEmpty) {
      DateTime current = DateTime(_today.year, _today.month, _today.day);
      DateTime earliest = workoutDates.reduce((a, b) => a.isBefore(b) ? a : b);
      bool isFirstDay = true;

      while (!current.isBefore(earliest)) {
        String dayName = MuscleWikiService.getDayLabel(current);
        bool isScheduled = scheduledDays.contains(dayName);
        bool hasWorkedOut = workoutDates.contains(current);

        if (hasWorkedOut) {
          streak++;
        } else {
          if (isScheduled) {
            if (!isFirstDay) {
              break; // missed a past scheduled day
            }
          }
        }
        current = current.subtract(const Duration(days: 1));
        isFirstDay = false;
      }
    }

    _dayStreak = streak;
    notifyListeners();
  }
}
