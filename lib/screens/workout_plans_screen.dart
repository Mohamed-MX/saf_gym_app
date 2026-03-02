import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/workout_plans_viewmodel.dart';
import '../models/workout_plan.dart';
import '../theme/app_theme.dart';
import 'workout_plan_editor_screen.dart';

class WorkoutPlansScreen extends StatelessWidget {
  const WorkoutPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkoutPlansViewModel(),
      child: const _WorkoutPlansView(),
    );
  }
}

class _WorkoutPlansView extends StatelessWidget {
  const _WorkoutPlansView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkoutPlansViewModel>();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(
          'My Plans',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        centerTitle: false,
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : vm.plans.isEmpty
              ? _buildEmpty(context)
              : RefreshIndicator(
                  color: AppTheme.primaryBlue,
                  onRefresh: () => context.read<WorkoutPlansViewModel>().loadPlans(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                    itemCount: vm.plans.length,
                    itemBuilder: (context, index) {
                      return _PlanCard(
                        plan: vm.plans[index],
                        onDelete: () => _confirmDelete(
                            context, vm, vm.plans[index]),
                        onEdit: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkoutPlanEditorScreen(
                                existingPlan: vm.plans[index],
                              ),
                            ),
                          );
                          if (context.mounted) {
                            context.read<WorkoutPlansViewModel>().loadPlans();
                          }
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WorkoutPlanEditorScreen(),
            ),
          );
          if (context.mounted) {
            context.read<WorkoutPlansViewModel>().loadPlans();
          }
        },
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: AppTheme.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Create Plan',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No plans yet',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Create Plan" to build\nyour first custom workout',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppTheme.mediumGrey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WorkoutPlansViewModel vm, WorkoutPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text('Delete "${plan.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await vm.deletePlan(plan.id);
    }
  }
}

// ── Plan Card ──────────────────────────────────────────────────────────────

class _PlanCard extends StatefulWidget {
  final WorkoutPlan plan;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _PlanCard({required this.plan, required this.onDelete, required this.onEdit});

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // ── Header ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryBlue, Color(0xFF1a7fe8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fitness_center, color: AppTheme.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.charcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _pill('${plan.days.length} days', Icons.calendar_today_rounded),
                            const SizedBox(width: 8),
                            _pill('${plan.totalExercises} exercises', Icons.sports_gymnastics),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Compact action buttons — no default 48×48 tap area inflation
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppTheme.primaryBlue,
                    onPressed: widget.onEdit,
                    tooltip: 'Edit',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppTheme.error,
                    onPressed: widget.onDelete,
                    tooltip: 'Delete',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.mediumGrey,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          // ── Expanded day list ──
          if (_expanded) ...[
            const Divider(height: 1),
            ...plan.days.map((day) => _DayRow(day: day)),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.mediumGrey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey)),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  final WorkoutDay day;
  const _DayRow({required this.day});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  day.dayName,
                  style: const TextStyle(color: AppTheme.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${day.exercises.length} exercise${day.exercises.length != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
              ),
            ],
          ),
          if (day.exercises.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...day.exercises.map((ex) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ex.name,
                          style: const TextStyle(fontSize: 13, color: AppTheme.charcoal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${ex.sets}×${ex.reps}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
