import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/workout_plan.dart';
import '../theme/app_theme.dart';
import '../ble/ble_manager.dart';
import '../logic/rep_game_logic.dart';

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

  @override
  void initState() {
    super.initState();
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
      setState(() {
        _completedSets[_currentIndex]++;
        _logic.reset();
        _isTracking = false;
      });
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
      });
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _logic.reset();
        _isTracking = false;
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
      body: Padding(
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
              ),
            ),
            const SizedBox(height: 20),

            // ── Navigation row ────────────────────────────────────────────
            Row(
              children: [
                // Previous button
                if (_currentIndex > 0)
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _prev,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16),
                      label: Text('Back',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.charcoal,
                        side: BorderSide(color: AppTheme.lightGrey),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull)),
                      ),
                    ),
                  ),
                if (_currentIndex > 0) const SizedBox(width: 12),

                // Next / Finish button
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _allSetsCompleted ? _next : null,
                    icon: Icon(
                      _isLast
                          ? Icons.check_circle_outline_rounded
                          : Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _isLast ? 'Finish Workout' : 'Next Exercise',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: AppTheme.white,
                      disabledBackgroundColor:
                          AppTheme.primaryBlue.withValues(alpha: 0.35),
                      disabledForegroundColor:
                          AppTheme.white.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull)),
                    ),
                  ),
                ),
              ],
            ),
          ],
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

  const _ExerciseCard({
    required this.exercise,
    required this.completedSets,
    required this.currentReps,
    required this.bleConnected,
    required this.isTracking,
    required this.onStartTracking,
    required this.onCompleteSet,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryBlue, Color(0xFF1a7fe8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.fitness_center_rounded,
                color: Colors.white, size: 40),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                exercise.muscleGroup!,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600),
              ),
            ),

          const Spacer(),

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
                  color: done
                      ? AppTheme.primaryBlue
                      : AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }),
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
                  onPressed: remaining > 0 ? onCompleteSet : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
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
                        remaining > 0 ? Icons.check_rounded : Icons.check_circle_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          remaining > 0 ? 'Complete ($remaining)' : 'Done ✓',
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
