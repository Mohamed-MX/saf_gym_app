import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/workout_plans_viewmodel.dart';
import '../models/workout_plan.dart';
import '../theme/app_theme.dart';
import '../services/muscle_wiki_service.dart';
import 'ai_workout_plan_screen.dart';
import 'muscle_selection_screen.dart';
import 'workout_plan_editor_screen.dart';
import 'workout_plans_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => WorkoutPlansViewModel()),
      ],
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final plansVm = context.watch<WorkoutPlansViewModel>();

    // Find today's workout day from plans
    final todayName = MuscleWikiService.getDayLabel(vm.today);
    WorkoutDay? todayWorkout;
    WorkoutPlan? todayPlan;
    for (final plan in plansVm.plans) {
      for (final day in plan.days) {
        if (day.dayName == todayName && day.exercises.isNotEmpty) {
          todayWorkout = day;
          todayPlan = plan;
          break;
        }
      }
      if (todayWorkout != null) break;
    }

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(
        slivers: [
          // ── Blue Header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _HomeHeader(vm: vm),
          ),

          // ── Action Cards ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Create Your Own Workout (blue card)
                  _CreateWorkoutCard(
                    onTap: () async {
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
                  ),
                  const SizedBox(height: 14),

                  // AI Workout Plan
                  _ActionCard(
                    icon: Icons.auto_awesome,
                    iconColor: AppTheme.primaryBlue,
                    title: 'AI Workout Plan',
                    subtitle: 'Customize your training',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AiWorkoutPlanScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Performance Dashboard
                  _ActionCard(
                    icon: Icons.bar_chart_rounded,
                    iconColor: AppTheme.primaryBlue,
                    title: 'Performance Dashboard',
                    subtitle: 'View your progress',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WorkoutPlansScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // ── Today's Plan ─────────────────────────────────────────
                  Text(
                    "Today's Plan",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TodaysPlanCard(
                    todayName: todayName,
                    planName: todayPlan?.name,
                    todayWorkout: todayWorkout,
                    isLoadingPlans: plansVm.isLoading,
                    onStart: () {
                      if (todayPlan != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkoutPlanEditorScreen(
                              existingPlan: todayPlan,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WorkoutPlanEditorScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header Widget ─────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final HomeViewModel vm;
  const _HomeHeader({required this.vm});

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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: title + profile
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Let's Move Today",
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ready to crush your goals?',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Profile avatar button
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const _ProfileSheet(),
                      );
                    },
                    child: Container(
                      width: 48,
                      height: 48,
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
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Stats row
              Row(
                children: [
                  _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Colors.redAccent,
                    value: '7',
                    label: 'Day streak',
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.fitness_center_rounded,
                    iconColor: AppTheme.charcoal,
                    value: '900',
                    label: 'Total Reps',
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.timer_rounded,
                    iconColor: AppTheme.primaryBlue,
                    value: '5k',
                    label: 'Minutes',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.mediumGrey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create Workout Card (blue) ────────────────────────────────────────────────

class _CreateWorkoutCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateWorkoutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryBlue,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Row(
            children: [
              // Plus circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: AppTheme.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Your Own Workout',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Build a Custom routine',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.white, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action Card (white) ───────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppTheme.mediumGrey, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Today's Plan Card ─────────────────────────────────────────────────────────

class _TodaysPlanCard extends StatelessWidget {
  final String todayName;
  final String? planName;
  final WorkoutDay? todayWorkout;
  final bool isLoadingPlans;
  final VoidCallback onStart;

  const _TodaysPlanCard({
    required this.todayName,
    required this.planName,
    required this.todayWorkout,
    required this.isLoadingPlans,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: isLoadingPlans
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day row + play button
                  Row(
                    children: [
                      Text(
                        planName != null ? '$planName — $todayName' : todayName,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.charcoal,
                        ),
                      ),
                      const Spacer(),
                      // Play / Start button
                      GestureDetector(
                        onTap: onStart,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppTheme.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Exercise list
                  if (todayWorkout == null || todayWorkout!.exercises.isEmpty)
                    _buildEmpty(context)
                  else
                    ...todayWorkout!.exercises.take(5).map(
                          (ex) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              '${ex.name} — ${ex.sets} sets × ${ex.reps} reps',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.darkGrey,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),

                  if ((todayWorkout?.exercises.length ?? 0) > 5)
                    Text(
                      '+ ${todayWorkout!.exercises.length - 5} more exercises',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No workout planned for today.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.mediumGrey,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onStart,
          child: Text(
            'Tap ▶ to create one now',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Profile Bottom Sheet ───────────────────────────────────────────────────────

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.mediumGrey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppTheme.charcoal,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: AppTheme.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            'Your Profile',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 24),

          // Edit Profile button
          _SheetButton(
            icon: Icons.edit_rounded,
            label: 'Edit Profile',
            iconColor: AppTheme.primaryBlue,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),

          // Log Out button
          _SheetButton(
            icon: Icons.logout_rounded,
            label: 'Log Out',
            iconColor: Colors.redAccent,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  const _SheetButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: iconColor.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

