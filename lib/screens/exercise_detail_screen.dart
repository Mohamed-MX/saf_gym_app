import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/muscle_wiki_service.dart';
import '../viewmodels/exercise_detail_viewmodel.dart';
import '../theme/app_theme.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final MuscleWikiExercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          ExerciseDetailViewModel()..checkFavorite(exercise.id),
      child: _ExerciseDetailView(exercise: exercise),
    );
  }
}

class _ExerciseDetailView extends StatelessWidget {
  final MuscleWikiExercise exercise;

  const _ExerciseDetailView({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExerciseDetailViewModel>();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(
        slivers: [
          // ── Image Header ──
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppTheme.primaryBlue,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: AppTheme.charcoal,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    vm.isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: vm.isFavorite ? Colors.red : AppTheme.charcoal,
                  ),
                ),
                onPressed: () async {
                  final result = await context
                      .read<ExerciseDetailViewModel>()
                      .toggleFavorite(exercise.id, exercise);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result
                              ? 'Added to favorites!'
                              : 'Removed from favorites',
                        ),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        backgroundColor: AppTheme.primaryBlue,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: exercise.displayImageUrl != null
                  ? Hero(
                      tag: 'exercise_image_${exercise.id}',
                      child: Image.network(
                        exercise.displayImageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color:
                                AppTheme.primaryBlue.withValues(alpha: 0.1),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, err, trace) => Container(
                          decoration: const BoxDecoration(
                            gradient: AppTheme.heroGradient,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.fitness_center,
                              size: 80,
                              color: AppTheme.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: AppTheme.heroGradient,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.fitness_center,
                          size: 80,
                          color: AppTheme.white,
                        ),
                      ),
                    ),
            ),
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Muscle / Difficulty badges ──
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (exercise.muscleSlug != null)
                        _badge(
                          MuscleWikiService.muscleDisplayNames[
                                  exercise.muscleSlug] ??
                              exercise.muscleSlug!,
                          AppTheme.primaryBlue,
                          AppTheme.white,
                        ),
                      if (exercise.difficulty != null)
                        _badge(
                          exercise.difficulty!,
                          AppTheme.primaryBlue.withValues(alpha: 0.1),
                          AppTheme.primaryBlue,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Name ──
                  Text(
                    exercise.name,
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Primary Muscles ──
                  if (exercise.primaryMuscles.isNotEmpty) ...[
                    _sectionTitle('Target Muscles'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: exercise.primaryMuscles.map((muscle) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                            border: Border.all(
                              color: AppTheme.primaryBlue
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.circle,
                                  size: 8, color: AppTheme.primaryBlue),
                              const SizedBox(width: 8),
                              Text(
                                muscle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Secondary Muscles ──
                  // (API does not provide secondary muscles in list endpoint)

                  // ── Equipment / Category ──
                  if (exercise.category != null &&
                      exercise.category!.isNotEmpty) ...[
                    _sectionTitle('Equipment'),
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue
                                  .withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: const Icon(
                              Icons.fitness_center,
                              color: AppTheme.primaryBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            exercise.category!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Instructions (Steps) ──
                  if (exercise.steps.isNotEmpty) ...[
                    _sectionTitle('Instructions'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: exercise.steps
                            .asMap()
                            .entries
                            .map((entry) {
                          final stepNum = entry.key + 1;
                          final stepText = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.only(
                                      top: 1, right: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$stepNum',
                                      style: const TextStyle(
                                        color: AppTheme.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    stepText,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.5,
                                      color: AppTheme.darkGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.charcoal,
          ),
        ),
      ],
    );
  }
}
