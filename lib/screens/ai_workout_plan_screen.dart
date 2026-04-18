import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/saf_database.dart';
import '../models/workout_plan.dart';
import 'saf_ai_model_exp.dart';

// ── Data Models ───────────────────────────────────────────────────────────────

enum TrainingGoal {
  strength('Strength', 'Low reps, High weight', Icons.fitness_center),
  hypertrophy('Hypertrophy', 'Muscle growth focused', Icons.accessibility_new_rounded),
  weightLoss('Weight Loss', 'Cardio & HIIT focused', Icons.local_fire_department_rounded);

  final String label;
  final String subtitle;
  final IconData icon;
  const TrainingGoal(this.label, this.subtitle, this.icon);
}

enum ExperienceLevel {
  beginner('Beginner', AiExperienceLevel.beginner),
  intermediate('Intermediate', AiExperienceLevel.intermediate),
  advanced('Advanced', AiExperienceLevel.advanced);

  final String label;
  final AiExperienceLevel aiLevel;
  const ExperienceLevel(this.label, this.aiLevel);
}

const List<String> _equipmentOptions = [
  'Barbell',
  'Dumbbells',
  'Machines',
  'Cables',
  'Bodyweight',
  'Kettlebells',
];

const List<String> _weekDays = [
  'Sun', 'Mon', 'Tue', 'Wen', 'Thu', 'Fri', 'Sat',
];

// ── Screen ────────────────────────────────────────────────────────────────────

class AiWorkoutPlanScreen extends StatefulWidget {
  const AiWorkoutPlanScreen({super.key});

  @override
  State<AiWorkoutPlanScreen> createState() => _AiWorkoutPlanScreenState();
}

class _AiWorkoutPlanScreenState extends State<AiWorkoutPlanScreen>
    with SingleTickerProviderStateMixin {
  // Training Goal is kept in state but not used in generation yet
  TrainingGoal _selectedGoal = TrainingGoal.hypertrophy;
  ExperienceLevel _selectedLevel = ExperienceLevel.intermediate;
  final Set<String> _selectedEquipment = {};
  final Set<String> _selectedDays = {};
  bool _isGenerating = false;

  late final AnimationController _buttonController;
  late final Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _buttonScale = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _buttonController.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────

  bool get _canGenerate =>
      _selectedDays.isNotEmpty && _selectedEquipment.isNotEmpty;

  void _showValidationSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Generate ────────────────────────────────────────────────────────────

  Future<void> _onGenerate() async {
    if (_selectedDays.isEmpty) {
      _showValidationSnack('Please select at least one training day.');
      return;
    }
    if (_selectedEquipment.isEmpty) {
      _showValidationSnack('Please select at least one equipment type.');
      return;
    }

    await _buttonController.reverse();
    await _buttonController.forward();

    setState(() => _isGenerating = true);

    WorkoutPlan? plan;
    String? errorMsg;

    try {
      plan = await SafAiModelExp.generateWorkout(
        level: _selectedLevel.aiLevel,
        equipment: Set.from(_selectedEquipment),
        selectedDays: Set.from(_selectedDays),
      );
    } catch (e) {
      errorMsg = 'Failed to generate plan. Check your connection and try again.';
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }

    if (!mounted) return;

    if (errorMsg != null || plan == null) {
      _showValidationSnack(errorMsg ?? 'Unknown error.');
      return;
    }

    // Show the plan preview popup
    _showPlanPopup(plan);
  }

  // ── Plan Preview Popup ──────────────────────────────────────────────────

  void _showPlanPopup(WorkoutPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlanPreviewSheet(
        plan: plan,
        onAccept: () async {
          await SafDatabase.instance.savePlan(plan);
          if (!mounted) return;
          Navigator.pop(context); // close sheet
          Navigator.pop(context); // go back to previous screen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ "${plan.name}" saved to your plans!'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          _AiPlanHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Training Goal (stored, not yet used in generation) ──
                  _SectionTitle('Training Goal'),
                  const SizedBox(height: 4),
                  const SizedBox(height: 12),
                  ...TrainingGoal.values.map(
                    (goal) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GoalCard(
                        goal: goal,
                        isSelected: _selectedGoal == goal,
                        onTap: () => setState(() => _selectedGoal = goal),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Experience Level ────────────────────────────────────
                  _SectionTitle('Experience Level'),
                  const SizedBox(height: 12),
                  Row(
                    children: ExperienceLevel.values.map((level) {
                      final isSelected = _selectedLevel == level;
                      return Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _LevelChip(
                            label: level.label,
                            isSelected: isSelected,
                            onTap: () =>
                                setState(() => _selectedLevel = level),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ── Available Equipment ─────────────────────────────────
                  _SectionTitle('Available Equipment'),
                  const SizedBox(height: 12),
                  _EquipmentGrid(
                    options: _equipmentOptions,
                    selected: _selectedEquipment,
                    onToggle: (item) => setState(() {
                      if (_selectedEquipment.contains(item)) {
                        _selectedEquipment.remove(item);
                      } else {
                        _selectedEquipment.add(item);
                      }
                    }),
                  ),

                  const SizedBox(height: 20),

                  // ── Days of the week ────────────────────────────────────
                  _SectionTitle('Choose Training Days'),
                  const SizedBox(height: 12),
                  _DaySelector(
                    days: _weekDays,
                    selected: _selectedDays,
                    onToggle: (day) => setState(() {
                      if (_selectedDays.contains(day)) {
                        _selectedDays.remove(day);
                      } else {
                        _selectedDays.add(day);
                      }
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _GenerateButton(
        isGenerating: _isGenerating,
        scaleAnimation: _buttonScale,
        canGenerate: _canGenerate,
        onTap: _isGenerating ? null : _onGenerate,
      ),
    );
  }
}
// ── Header ─────────────────────────────────────────────────────────────────────

class _AiPlanHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryBlue, Color(0xFF0A6DD4)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppTheme.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Workout Plan',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Personalized training program',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.charcoal,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Title ──────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.charcoal,
      ),
    );
  }
}

// ── Goal Card ──────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final TrainingGoal goal;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.goal,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isSelected ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                        : AppTheme.lightGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    goal.icon,
                    color: isSelected
                        ? AppTheme.primaryBlue
                        : AppTheme.mediumGrey,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.label,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      goal.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Experience Level Chip ──────────────────────────────────────────────────────

class _LevelChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.lightGrey,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.white : AppTheme.charcoal,
          ),
        ),
      ),
    );
  }
}

// ── Equipment Grid ─────────────────────────────────────────────────────────────

class _EquipmentGrid extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final void Function(String) onToggle;

  const _EquipmentGrid({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemCount: options.length,
      itemBuilder: (_, i) {
        final item = options[i];
        final isSelected = selected.contains(item);
        return GestureDetector(
          onTap: () => onToggle(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.12)
                  : AppTheme.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isSelected ? AppTheme.primaryBlue : AppTheme.lightGrey,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              item,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color:
                    isSelected ? AppTheme.primaryBlue : AppTheme.charcoal,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Day Selector ───────────────────────────────────────────────────────────────

class _DaySelector extends StatelessWidget {
  final List<String> days;
  final Set<String> selected;
  final void Function(String) onToggle;

  const _DaySelector({
    required this.days,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final firstRow = days.sublist(0, 4);
    final secondRow = days.sublist(4);

    return Column(
      children: [
        Row(
          children: firstRow
              .map(
                (d) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _DayChip(
                      label: d,
                      isSelected: selected.contains(d),
                      onTap: () => onToggle(d),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: secondRow
              .map(
                (d) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                    width: 88,
                    child: _DayChip(
                      label: d,
                      isSelected: selected.contains(d),
                      onTap: () => onToggle(d),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.lightGrey,
          borderRadius: BorderRadius.circular(50),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.white : AppTheme.darkGrey,
          ),
        ),
      ),
    );
  }
}

// ── Generate Button ────────────────────────────────────────────────────────────

class _GenerateButton extends StatelessWidget {
  final bool isGenerating;
  final bool canGenerate;
  final Animation<double> scaleAnimation;
  final VoidCallback? onTap;

  const _GenerateButton({
    required this.isGenerating,
    required this.canGenerate,
    required this.scaleAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.offWhite,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 12,
      ),
      child: ScaleTransition(
        scale: scaleAnimation,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 60,
              decoration: BoxDecoration(
                gradient: canGenerate
                    ? const LinearGradient(
                        colors: [AppTheme.primaryBlue, Color(0xFF0A80E8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : LinearGradient(
                        colors: [
                          AppTheme.mediumGrey.withValues(alpha: 0.5),
                          AppTheme.mediumGrey.withValues(alpha: 0.5),
                        ],
                      ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: canGenerate
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: isGenerating
                  ? const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          color: AppTheme.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppTheme.white,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Generate AI Plan',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Plan Preview Bottom Sheet ──────────────────────────────────────────────────

class _PlanPreviewSheet extends StatefulWidget {
  final WorkoutPlan plan;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  const _PlanPreviewSheet({
    required this.plan,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  State<_PlanPreviewSheet> createState() => _PlanPreviewSheetState();
}

class _PlanPreviewSheetState extends State<_PlanPreviewSheet> {
  final Set<int> _expandedDays = {0}; // first day open by default
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.offWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── Sheet header ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppTheme.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.charcoal,
                            ),
                          ),
                          Text(
                            '${plan.days.length} days · ${plan.totalExercises} exercises',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.lightGrey),

              // ── Day accordion list ───────────────────────────────────
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  itemCount: plan.days.length,
                  itemBuilder: (_, dayIdx) {
                    final day = plan.days[dayIdx];
                    final isExpanded = _expandedDays.contains(dayIdx);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Day header tap
                            InkWell(
                              onTap: () => setState(() {
                                if (isExpanded) {
                                  _expandedDays.remove(dayIdx);
                                } else {
                                  _expandedDays.add(dayIdx);
                                }
                              }),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isExpanded
                                            ? AppTheme.primaryBlue
                                            : AppTheme.lightGrey,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${dayIdx + 1}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: isExpanded
                                                ? AppTheme.white
                                                : AppTheme.darkGrey,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        day.dayName,
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.charcoal,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${day.exercises.length} exercises',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.mediumGrey,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: AppTheme.mediumGrey,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Exercise cards (expanded)
                            if (isExpanded)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 0, 12, 12),
                                child: Column(
                                  children: day.exercises.map((ex) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8),
                                      child: _ExercisePreviewRow(
                                          exercise: ex),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Accept / Cancel buttons ──────────────────────────────
              const Divider(height: 1, color: AppTheme.lightGrey),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 16),
                child: Row(
                  children: [
                    // Cancel
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.darkGrey,
                          side: const BorderSide(color: AppTheme.lightGrey),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Accept
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setState(() => _isSaving = true);
                                widget.onAccept();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: AppTheme.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Accept Plan',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Exercise Preview Row ───────────────────────────────────────────────────────

class _ExercisePreviewRow extends StatelessWidget {
  final PlannedExercise exercise;
  const _ExercisePreviewRow({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.offWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Thumbnail or placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: exercise.thumbnailUrl != null
                ? Image.network(
                    exercise.thumbnailUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          // Name & muscle group
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((exercise.muscleGroup ?? '').isNotEmpty)
                  Text(
                    exercise.muscleGroup!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.mediumGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Sets × Reps badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${exercise.sets}×${exercise.reps}',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.fitness_center,
        color: AppTheme.mediumGrey,
        size: 20,
      ),
    );
  }
}
