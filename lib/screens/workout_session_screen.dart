import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ble/ble_manager.dart';
import '../logic/rep_game_logic.dart';
import '../models/workout_plan.dart';
import '../services/muscle_wiki_service.dart';
import '../services/saf_database.dart';
import '../theme/app_theme.dart';
import 'exercise_detail_screen.dart';

/// Displays a guided workout session for a single [WorkoutDay].
/// The user can step through each exercise and mark sets as done.
class WorkoutSessionScreen extends StatefulWidget {
  final WorkoutDay day;
  final String planName;

  const WorkoutSessionScreen({
    super.key,
    required this.day,
    required this.planName,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  int _currentIndex = 0;

  /// Track how many sets are completed per exercise index.
  late final List<int> _completedSets;

  final BleManager _bleManager = BleManager();
  final RepGameLogic _logic = RepGameLogic();
  bool _bleConnected = false;
  bool _isTracking = false;

  late final int _sessionId;
  late DateTime _lastSetEndTime;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch;
    _lastSetEndTime = DateTime.now();
    _completedSets =
        List.filled(widget.day.exercises.length, 0);
    _initBle();
  }

  void _initBle() {
    _bleManager.onDataCallback = (ax, ay, az) {
      if (!mounted) return;

      if (!_bleConnected) {
        setState(() => _bleConnected = true);
      }

      if (!_isTracking) return;
      
      setState(() {
        _logic.updateSensor(ax, ay, az);
        
        // Auto-complete set when reps reached
        if (_logic.reps >= _current.reps) {
          if (_completedSets[_currentIndex] < _current.sets) {
            _completeSet();
            _isTracking = false;
          }
        }
      });
    };
    _bleManager.startScan();
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
      _logic.reset();
    });
  }

  PlannedExercise get _current =>
      widget.day.exercises[_currentIndex];

  bool get _isLast =>
      _currentIndex == widget.day.exercises.length - 1;

  bool get _allSetsCompleted =>
      _completedSets[_currentIndex] >= _current.sets;

  void _completeSet() {
    if (_completedSets[_currentIndex] < _current.sets) {
      final int repsDone = _isTracking && _logic.reps > 0 ? _logic.reps : _current.reps;
      final now = DateTime.now();
      final timeTaken = now.difference(_lastSetEndTime).inSeconds;
      
      SafDatabase.instance.logPerformance({
        'session_id': _sessionId,
        'date_time': now.millisecondsSinceEpoch,
        'time_taken_seconds': timeTaken < 0 ? 0 : timeTaken,
        'workout_name': widget.planName,
        'exercise_name': _current.name,
        'reps': repsDone,
        'weight': _current.weights[_completedSets[_currentIndex]],
      });

      setState(() {
        _completedSets[_currentIndex]++;
        _logic.reset();
        _isTracking = false;
        _lastSetEndTime = DateTime.now();
      });
    }
  }

  void _updateWeight(int setIndex, double newWeight) async {
    setState(() {
      _current.weights[setIndex] = newWeight;
    });

    final plans = await SafDatabase.instance.getPlans();
    final plan = plans.where((p) => p.name == widget.planName).firstOrNull;
    if (plan != null) {
      for (final day in plan.days) {
        if (day.dayName == widget.day.dayName) {
          final idx = day.exercises.indexWhere((e) => e.exerciseId == _current.exerciseId);
          if (idx != -1) {
            day.exercises[idx].weights[setIndex] = newWeight;
          }
        }
      }
      await SafDatabase.instance.savePlan(plan);
    }
  }

  void _next() {
    if (_isLast) {
      _showFinishedDialog();
    } else {
      setState(() {
        _currentIndex++;
        _logic.reset();
        _isTracking = false;
        _lastSetEndTime = DateTime.now();
      });
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _logic.reset();
        _isTracking = false;
        _lastSetEndTime = DateTime.now();
      });
    }
  }

  void _showFinishedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        title: Column(
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: Colors.amber, size: 52),
            const SizedBox(height: 8),
            Text(
              'Workout Complete!',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800, fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          'Great job finishing ${widget.day.dayName}\'s workout.',
          style: const TextStyle(color: AppTheme.mediumGrey),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: AppTheme.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // back to plans
            },
            child: Text('Done',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.day.exercises;

    if (exercises.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.offWhite,
        appBar: AppBar(
          title: Text(widget.day.dayName,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          backgroundColor: AppTheme.offWhite,
          elevation: 0,
          foregroundColor: AppTheme.charcoal,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fitness_center_outlined,
                  size: 64, color: AppTheme.mediumGrey),
              const SizedBox(height: 16),
              Text('No exercises in this day',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mediumGrey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.planName,
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppTheme.mediumGrey),
            ),
            Text(
              widget.day.dayName,
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
        foregroundColor: AppTheme.charcoal,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sensor',
                  style: GoogleFonts.outfit(
                    color: _bleConnected ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.bluetooth_rounded,
                  color: _bleConnected ? Colors.green : Colors.redAccent,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Progress bar ──────────────────────────────────────────────
            _ProgressBar(
                current: _currentIndex + 1, total: exercises.length),
            const SizedBox(height: 20),

            // ── Exercise card ─────────────────────────────────────────────
            Expanded(
              child: _ExerciseCard(
                exercise: _current,
                completedSets: _completedSets[_currentIndex],
                currentReps: _logic.reps,
                bleConnected: _bleConnected,
                isTracking: _isTracking,
                onStartTracking: _startTracking,
                onCompleteSet: _completeSet,
                onWeightChanged: _updateWeight,
                onPrev: _prev,
                onNext: _next,
                isFirst: _currentIndex == 0,
                isLast: _isLast,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ── Progress Bar ────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 8,
              backgroundColor: AppTheme.lightGrey,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$current / $total',
          style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.mediumGrey),
        ),
      ],
    );
  }
}

// ── Exercise Card ────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final PlannedExercise exercise;
  final int completedSets;
  final int currentReps;
  final bool bleConnected;
  final bool isTracking;
  final VoidCallback onStartTracking;
  final VoidCallback onCompleteSet;
  final void Function(int setIndex, double newWeight)? onWeightChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool isFirst;
  final bool isLast;

  const _ExerciseCard({
    required this.exercise,
    required this.completedSets,
    required this.currentReps,
    required this.bleConnected,
    required this.isTracking,
    required this.onStartTracking,
    required this.onCompleteSet,
    this.onWeightChanged,
    required this.onPrev,
    required this.onNext,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = exercise.sets - completedSets;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon / Thumbnail
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: isFirst ? null : onPrev,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: isFirst ? Colors.transparent : AppTheme.mediumGrey,
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExerciseDetailScreen(
                                exercise: MuscleWikiExercise(
                                  id: exercise.exerciseId,
                                  name: exercise.name,
                                  primaryMuscles: exercise.muscleGroup != null ? [exercise.muscleGroup!] : [],
                                  steps: [],
                                  thumbnailUrl: exercise.thumbnailUrl,
                                ),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: exercise.thumbnailUrl == null ? AppTheme.primaryBlue : AppTheme.lightGrey,
                            borderRadius: BorderRadius.circular(20),
                            image: exercise.thumbnailUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(exercise.thumbnailUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            boxShadow: [
                              if (exercise.thumbnailUrl != null)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: exercise.thumbnailUrl == null
                              ? const Icon(Icons.fitness_center_rounded, color: AppTheme.white, size: 40)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onNext,
                        icon: Icon(isLast ? Icons.check_circle_outline_rounded : Icons.arrow_forward_ios_rounded),
                        color: isLast ? Colors.green : AppTheme.mediumGrey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Exercise name
                  Text(
                    exercise.name,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.charcoal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Muscle group chip
                  if (exercise.muscleGroup != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        exercise.muscleGroup!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // GIF
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/flapppy-gym.gif',
                      fit: BoxFit.cover,
                      height: 120,
                      width: double.infinity,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sets × Reps info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatBlock(label: 'Sets', value: '${exercise.sets}'),
                      const _Divider(),
                      _StatBlock(label: 'Reps', value: '${exercise.reps}'),
                      const _Divider(),
                      _StatBlock(
                          label: 'Done',
                          value: '$completedSets',
                          valueColor: AppTheme.primaryBlue),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Rep dots
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(exercise.reps, (i) {
                      final done = i < currentReps || completedSets >= exercise.sets;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: done ? 16 : 12,
                        height: done ? 16 : 12,
                        decoration: BoxDecoration(
                          color: done ? AppTheme.primaryBlue : AppTheme.lightGrey,
                          shape: BoxShape.circle,
                          boxShadow: done
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  // Set dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(exercise.sets, (i) {
                      final done = i < completedSets;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: done ? 32 : 24,
                        height: 12,
                        decoration: BoxDecoration(
                          color: done ? AppTheme.primaryBlue : AppTheme.lightGrey,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // Sets List (with weights)
                  Column(
                    children: List.generate(exercise.sets, (i) {
                      final isCurrent = i == completedSets;
                      final isDone = i < completedSets;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isDone ? AppTheme.primaryBlue : (isCurrent ? Colors.amber : AppTheme.lightGrey),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(isDone ? Icons.check : Icons.fitness_center, size: 12, color: AppTheme.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('Set ${i + 1}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isCurrent ? AppTheme.charcoal : AppTheme.mediumGrey)),
                            const Spacer(),
                            _WeightControl(
                              value: exercise.weights[i],
                              onDecrement: () {
                                if (exercise.weights[i] > 0 && onWeightChanged != null) {
                                  onWeightChanged!(i, exercise.weights[i] - 1.0);
                                }
                              },
                              onIncrement: () {
                                if (onWeightChanged != null) {
                                  onWeightChanged!(i, exercise.weights[i] + 1.0);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text('KG', style: TextStyle(fontSize: 10, color: AppTheme.mediumGrey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Buttons Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (!bleConnected || remaining <= 0 || isTracking) ? null : onStartTracking,
                  icon: Icon(
                    isTracking ? Icons.sensors_rounded : Icons.play_arrow_rounded,
                    size: 20,
                  ),
                  label: Text(
                    isTracking ? 'Tracking' : 'Start',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.charcoal,
                    foregroundColor: AppTheme.white,
                    disabledBackgroundColor: isTracking ? AppTheme.charcoal.withValues(alpha: 0.5) : AppTheme.lightGrey,
                    disabledForegroundColor: isTracking ? AppTheme.white : AppTheme.mediumGrey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: remaining > 0 ? onCompleteSet : onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: remaining > 0 ? AppTheme.primaryBlue : Colors.green,
                    foregroundColor: AppTheme.white,
                    disabledBackgroundColor: Colors.green.withValues(alpha: 0.15),
                    disabledForegroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        remaining > 0 ? Icons.check_rounded : (isLast ? Icons.emoji_events_rounded : Icons.arrow_forward_ios_rounded),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          remaining > 0 ? 'Complete ($remaining)' : (isLast ? 'Finish Workout' : 'Next Exercise'),
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatBlock(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppTheme.charcoal,
          ),
        ),
        Text(
          label,
          style:
              const TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppTheme.lightGrey,
    );
  }
}

class _WeightControl extends StatelessWidget {
  final double value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _WeightControl({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Btn(icon: Icons.remove, onTap: onDecrement),
        SizedBox(
          width: 36,
          child: Text(
            value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        _Btn(icon: Icons.add, onTap: onIncrement),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 12, color: AppTheme.primaryBlue),
      ),
    );
  }
}

