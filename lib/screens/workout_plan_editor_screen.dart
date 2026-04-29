import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/workout_plan_editor_viewmodel.dart';
import '../models/workout_plan.dart';
import '../theme/app_theme.dart';
import 'exercise_picker_screen.dart';

class WorkoutPlanEditorScreen extends StatelessWidget {
  final WorkoutPlan? existingPlan;
  const WorkoutPlanEditorScreen({super.key, this.existingPlan});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final vm = WorkoutPlanEditorViewModel();
        if (existingPlan != null) vm.loadPlan(existingPlan!);
        return vm;
      },
      child: _EditorView(existingPlan: existingPlan),
    );
  }
}

class _EditorView extends StatelessWidget {
  final WorkoutPlan? existingPlan;
  const _EditorView({this.existingPlan});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkoutPlanEditorViewModel>();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(
          existingPlan == null ? 'New Plan' : 'Edit Plan',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (vm.isValid)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton(
                onPressed: vm.isSaving
                    ? null
                    : () async {
                        final plan = await vm.savePlan(
                            existingId: existingPlan?.id);
                        if (plan != null && context.mounted) {
                          Navigator.pop(context, plan);
                        }
                      },
                child: vm.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryBlue,
                        ),
                      )
                    : Text(
                        'Save',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Plan Name ──────────────────────────────────────────────────
            _SectionHeader(icon: Icons.edit_note_rounded, title: 'Plan Name'),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: vm.planName)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: vm.planName.length),
                ),
              onChanged: (v) {
                context
                    .read<WorkoutPlanEditorViewModel>()
                    .setPlanName(v);
              },
              decoration: InputDecoration(
                hintText: 'e.g. Push Pull Legs, Full Body...',
                hintStyle: TextStyle(color: AppTheme.mediumGrey),
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 28),

            // ── Days ───────────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.calendar_month_rounded,
              title: 'Select Days',
              subtitle: '${vm.selectedDays.length} selected',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: WorkoutPlanEditorViewModel.weekDays.map((day) {
                final isSelected = vm.selectedDays.contains(day);
                final shortDay = day.substring(0, 3);
                return GestureDetector(
                  onTap: () =>
                      context.read<WorkoutPlanEditorViewModel>().toggleDay(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : AppTheme.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryBlue
                            : AppTheme.lightGrey,
                        width: 2,
                      ),
                      boxShadow: isSelected ? [] : AppTheme.cardShadow,
                    ),
                    child: Center(
                      child: Text(
                        shortDay,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppTheme.white : AppTheme.charcoal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Per-Day Exercise Builders ──────────────────────────────────
            if (vm.selectedDays.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionHeader(
                icon: Icons.fitness_center_rounded,
                title: 'Exercises',
                subtitle: '${vm.totalExerciseCount} total',
              ),
              const SizedBox(height: 12),
              ...WorkoutPlanEditorViewModel.weekDays
                  .where((d) => vm.selectedDays.contains(d))
                  .map((day) => _DayExerciseBuilder(day: day)),
            ],

            // ── Error ──────────────────────────────────────────────────────
            if (vm.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(vm.error!,
                          style: TextStyle(color: AppTheme.error, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),

      // ── Bottom Save Bar ────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: ElevatedButton(
            onPressed: (!vm.isValid || vm.isSaving)
                ? null
                : () async {
                    final plan =
                        await vm.savePlan(existingId: existingPlan?.id);
                    if (plan != null && context.mounted) {
                      Navigator.pop(context, plan);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              disabledBackgroundColor: AppTheme.lightGrey,
              foregroundColor: AppTheme.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              elevation: 0,
            ),
            child: vm.isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.white),
                  )
                : Text(
                    existingPlan == null ? 'Save Plan' : 'Update Plan',
                    style: GoogleFonts.outfit(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Day Exercise Builder ──────────────────────────────────────────────────

class _DayExerciseBuilder extends StatelessWidget {
  final String day;
  const _DayExerciseBuilder({required this.day});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkoutPlanEditorViewModel>();
    final exercises = vm.exercisesForDay(day);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${exercises.length} exercise${exercises.length != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                ),
                const Spacer(),
                // Add exercises button
                TextButton.icon(
                  onPressed: () async {
                    final picked = await Navigator.push<List<PlannedExercise>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExercisePickerScreen(targetDay: day),
                      ),
                    );
                    if (picked != null && picked.isNotEmpty && context.mounted) {
                      context
                          .read<WorkoutPlanEditorViewModel>()
                          .addExercisesToDay(day, picked);
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),

          // Exercise list (reorderable)
          if (exercises.isNotEmpty) ...[
            const Divider(height: 1),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exercises.length,
              onReorder: (oldIndex, newIndex) {
                context
                    .read<WorkoutPlanEditorViewModel>()
                    .reorderExercise(day, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final ex = exercises[index];
                return _ExerciseRow(
                  key: ValueKey('${day}_${ex.exerciseId}_$index'),
                  exercise: ex,
                  index: index,
                  day: day,
                );
              },
            ),
          ],

          if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Tap + Add to pick exercises for this day',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.mediumGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Exercise Row in Editor ────────────────────────────────────────────────

class _ExerciseRow extends StatelessWidget {
  final PlannedExercise exercise;
  final int index;
  final String day;

  const _ExerciseRow({
    super.key,
    required this.exercise,
    required this.index,
    required this.day,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: exercise.thumbnailUrl != null
                      ? Image.network(
                          exercise.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, err, _) => Container(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            child: const Icon(Icons.fitness_center,
                                size: 28, color: AppTheme.primaryBlue),
                          ),
                        )
                      : Container(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          child: const Icon(Icons.fitness_center,
                              size: 28, color: AppTheme.primaryBlue),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + muscle + sets/reps
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row with delete & drag
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.charcoal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Delete
                        GestureDetector(
                          onTap: () => context
                              .read<WorkoutPlanEditorViewModel>()
                              .removeExerciseFromDay(day, index),
                          child: const Icon(Icons.close, size: 20, color: AppTheme.error),
                        ),
                        const SizedBox(width: 16),
                        // Drag handle
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle, size: 24, color: AppTheme.mediumGrey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Muscle row with sets/reps
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            exercise.muscleGroup ?? 'Unknown Muscle',
                            style: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Sets / Reps
                        _SetsRepsControl(
                          label: 'Sets',
                          value: exercise.sets,
                          onDecrement: () {
                            if (exercise.sets > 1) {
                              context
                                  .read<WorkoutPlanEditorViewModel>()
                                  .updateSets(day, index, exercise.sets - 1);
                            }
                          },
                          onIncrement: () {
                            context
                                .read<WorkoutPlanEditorViewModel>()
                                .updateSets(day, index, exercise.sets + 1);
                          },
                        ),
                        const SizedBox(width: 12),
                        _SetsRepsControl(
                          label: 'Reps',
                          value: exercise.reps,
                          onDecrement: () {
                            if (exercise.reps > 1) {
                              context
                                  .read<WorkoutPlanEditorViewModel>()
                                  .updateReps(day, index, exercise.reps - 1);
                            }
                          },
                          onIncrement: () {
                            context
                                .read<WorkoutPlanEditorViewModel>()
                                .updateReps(day, index, exercise.reps + 1);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (exercise.sets > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 82), // align with text (70 image + 12 gap)
              child: Column(
                children: List.generate(exercise.sets, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text('Set ${i + 1} Weight', style: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey)),
                        const Spacer(),
                        _WeightControl(
                          value: exercise.weights[i],
                          onDecrement: () {
                            if (exercise.weights[i] > 0) {
                              context.read<WorkoutPlanEditorViewModel>().updateWeight(day, index, i, exercise.weights[i] - 1.0);
                            }
                          },
                          onIncrement: () {
                            context.read<WorkoutPlanEditorViewModel>().updateWeight(day, index, i, exercise.weights[i] + 1.0);
                          },
                        ),
                        const SizedBox(width: 4),
                        const Text('KG', style: TextStyle(fontSize: 10, color: AppTheme.mediumGrey, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 36), // Align with drag handle
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
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

class _SetsRepsControl extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _SetsRepsControl({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.mediumGrey)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Btn(icon: Icons.remove, onTap: onDecrement),
            SizedBox(
              width: 24,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            _Btn(icon: Icons.add, onTap: onIncrement),
          ],
        ),
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

// ── Section Header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryBlue),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.charcoal,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
