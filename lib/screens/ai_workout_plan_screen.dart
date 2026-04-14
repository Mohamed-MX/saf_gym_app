import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

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
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  final String label;
  const ExperienceLevel(this.label);
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
  'Sun',
  'Mon',
  'Tue',
  'Wen',
  'Thu',
  'Fri',
  'Sat',
];

// ── Screen ────────────────────────────────────────────────────────────────────

class AiWorkoutPlanScreen extends StatefulWidget {
  const AiWorkoutPlanScreen({super.key});

  @override
  State<AiWorkoutPlanScreen> createState() => _AiWorkoutPlanScreenState();
}

class _AiWorkoutPlanScreenState extends State<AiWorkoutPlanScreen>
    with SingleTickerProviderStateMixin {
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

  Future<void> _onGenerate() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one training day.'),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    await _buttonController.reverse();
    await _buttonController.forward();

    setState(() => _isGenerating = true);

    // Simulate AI generation delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isGenerating = false);

    // TODO: Navigate to generated plan result screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'AI Plan generated! Goal: ${_selectedGoal.label} · '
          'Level: ${_selectedLevel.label} · Days: ${_selectedDays.join(", ")}',
        ),
        backgroundColor: AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          // ── Blue Header ──────────────────────────────────────────────────
          _AiPlanHeader(),

          // ── Scrollable Body ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Training Goal
                  _SectionTitle('Training Goal'),
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

                  // Experience Level
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
                            onTap: () => setState(() => _selectedLevel = level),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Available Equipment
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

                  // Days of the week
                  _SectionTitle('Choose how many days of the week'),
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

      // ── Generate Button ──────────────────────────────────────────────────
      bottomNavigationBar: _GenerateButton(
        isGenerating: _isGenerating,
        scaleAnimation: _buttonScale,
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
              // Back button
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
              // Title & subtitle
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
              // Avatar
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
                  Icons.person_rounded,
                  color: AppTheme.white,
                  size: 24,
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
                // Icon container
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
                    color: isSelected ? AppTheme.primaryBlue : AppTheme.mediumGrey,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                // Labels
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
                color: isSelected ? AppTheme.primaryBlue : AppTheme.lightGrey,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              item,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppTheme.primaryBlue : AppTheme.charcoal,
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
    // Two rows: first 4 days, then last 3
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
  final Animation<double> scaleAnimation;
  final VoidCallback? onTap;

  const _GenerateButton({
    required this.isGenerating,
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
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryBlue, Color(0xFF0A80E8)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
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
