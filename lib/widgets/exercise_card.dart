import 'package:flutter/material.dart';
import '../services/muscle_wiki_service.dart';
import '../theme/app_theme.dart';

class ExerciseCard extends StatelessWidget {
  final MuscleWikiExercise exercise;
  final VoidCallback onTap;
  final int index;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Row(
            children: [
              // ── Exercise Image / GIF ──────────────────────────────────
              Hero(
                tag: 'exercise_image_${exercise.id}',
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  ),
                  child: exercise.displayImageUrl != null
                      ? Image.network(
                          exercise.displayImageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryBlue,
                              ),
                            );
                          },
                          errorBuilder: (context, err, trace) => const Icon(
                            Icons.fitness_center,
                            color: AppTheme.primaryBlue,
                            size: 40,
                          ),
                        )
                      : const Icon(
                          Icons.fitness_center,
                          color: AppTheme.primaryBlue,
                          size: 40,
                        ),
                ),
              ),
              // ── Details ───────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(
                                color: AppTheme.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (exercise.difficulty != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusFull),
                              ),
                              child: Text(
                                exercise.difficulty!,
                                style: const TextStyle(
                                  color: AppTheme.primaryBlue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Name
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.charcoal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Primary muscles
                      if (exercise.primaryMuscles.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.sports_gymnastics,
                              size: 14,
                              color: AppTheme.mediumGrey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                exercise.primaryMusclesLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.darkGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              // Arrow
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.chevron_right,
                  color: AppTheme.mediumGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
