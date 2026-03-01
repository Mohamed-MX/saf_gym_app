import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/exercise.dart';
import '../services/wger_api_service.dart';
import '../services/favorites_service.dart';
import '../widgets/exercise_card.dart';
import '../widgets/shimmer_loading.dart';
import '../theme/app_theme.dart';
import 'exercise_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesService _favoritesService = FavoritesService();
  final WgerApiService _apiService = WgerApiService();

  List<Exercise> _exercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload favorites when returning to this screen
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);

    try {
      final favoriteIds = await _favoritesService.getFavorites();
      if (favoriteIds.isEmpty) {
        if (mounted) {
          setState(() {
            _exercises = [];
            _isLoading = false;
          });
        }
        return;
      }

      final exercises = await _apiService.getExercisesByIds(favoriteIds);
      if (mounted) {
        setState(() {
          _exercises = exercises;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: List.generate(
                  4,
                  (index) => const ExerciseCardShimmer(),
                ),
              ),
            )
          : _exercises.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppTheme.primaryBlue,
                  onRefresh: _loadFavorites,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _exercises[index];
                      return Dismissible(
                        key: Key('fav_${exercise.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin:
                              const EdgeInsets.only(bottom: AppTheme.spacingMd),
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
                          await _favoritesService.removeFavorite(exercise.id);
                          setState(() {
                            _exercises.removeAt(index);
                          });
                          if (mounted) {
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
                                    ExerciseDetailScreen(exercise: exercise),
                              ),
                            );
                            // Reload favorites after returning
                            _loadFavorites();
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
