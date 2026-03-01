import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/exercise.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final FavoritesService _favoritesService = FavoritesService();
  bool _isFavorite = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final isFav = await _favoritesService.isFavorite(widget.exercise.id);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _toggleFavorite() async {
    final result = await _favoritesService.toggleFavorite(widget.exercise.id);
    if (mounted) {
      setState(() => _isFavorite = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result ? 'Added to favorites!' : 'Removed from favorites',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          backgroundColor: AppTheme.primaryBlue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;

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
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: _isFavorite ? Colors.red : AppTheme.charcoal,
                  ),
                ),
                onPressed: _toggleFavorite,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: exercise.images.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image carousel
                        PageView.builder(
                          itemCount: exercise.images.length,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                          },
                          itemBuilder: (context, index) {
                            return Hero(
                              tag: index == 0
                                  ? 'exercise_image_${exercise.id}'
                                  : 'exercise_image_${exercise.id}_$index',
                              child: CachedNetworkImage(
                                imageUrl: exercise.images[index].image,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppTheme.primaryBlue
                                      .withValues(alpha: 0.1),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    Container(
                                  color: AppTheme.primaryBlue
                                      .withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.fitness_center,
                                    size: 80,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        // Image indicators
                        if (exercise.images.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                exercise.images.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width:
                                      index == _currentImageIndex ? 24 : 8,
                                  height: 8,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    color: index == _currentImageIndex
                                        ? AppTheme.white
                                        : AppTheme.white
                                            .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusFull),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
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
                  // Category badge
                  if (exercise.categoryName.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        exercise.categoryName,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Exercise name
                  Text(
                    exercise.name,
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Target Muscles ──
                  if (exercise.muscles.isNotEmpty) ...[
                    _buildSectionTitle('Target Muscles'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: exercise.muscles.map((muscle) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                            border: Border.all(
                              color:
                                  AppTheme.primaryBlue.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 8,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                muscle.displayName,
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
                  if (exercise.musclesSecondary.isNotEmpty) ...[
                    _buildSectionTitle('Secondary Muscles'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: exercise.musclesSecondary.map((muscle) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGrey,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            muscle.displayName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Equipment ──
                  if (exercise.equipment.isNotEmpty) ...[
                    _buildSectionTitle('Equipment Needed'),
                    const SizedBox(height: 12),
                    ...exercise.equipment.map((eq) {
                      return Container(
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
                              eq.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.charcoal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // ── Description ──
                  if (exercise.description.isNotEmpty) ...[
                    _buildSectionTitle('Instructions'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Text(
                        exercise.description,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: AppTheme.darkGrey,
                        ),
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

  Widget _buildSectionTitle(String title) {
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
