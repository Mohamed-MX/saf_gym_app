import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/favorites_viewmodel.dart';
import '../widgets/exercise_card.dart';
import '../widgets/shimmer_loading.dart';
import '../theme/app_theme.dart';
import 'exercise_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FavoritesViewModel()..loadFavorites(),
      child: const _FavoritesView(),
    );
  }
}

class _FavoritesView extends StatefulWidget {
  const _FavoritesView();

  @override
  State<_FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends State<_FavoritesView> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<FavoritesViewModel>().loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavoritesViewModel>();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(
          'Favorites',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
      ),
      body: vm.isLoading
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: List.generate(
                  4,
                  (index) => const ExerciseCardShimmer(),
                ),
              ),
            )
          : vm.exercises.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppTheme.primaryBlue,
                  onRefresh: () =>
                      context.read<FavoritesViewModel>().loadFavorites(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: vm.exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = vm.exercises[index];
                      return Dismissible(
                        key: Key('fav_${exercise.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(
                              bottom: AppTheme.spacingMd),
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.white,
                          ),
                        ),
                        onDismissed: (direction) async {
                          await context
                              .read<FavoritesViewModel>()
                              .removeFavorite(exercise.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('${exercise.name} removed'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm),
                                ),
                                backgroundColor: AppTheme.charcoal,
                              ),
                            );
                          }
                        },
                        child: ExerciseCard(
                          exercise: exercise,
                          index: index,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ExerciseDetailScreen(
                                        exercise: exercise),
                              ),
                            );
                            if (context.mounted) {
                              context
                                  .read<FavoritesViewModel>()
                                  .loadFavorites();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
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
                Icons.favorite_border,
                size: 48,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No favorites yet',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart icon on any exercise\nto save it here for quick access',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.mediumGrey,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
