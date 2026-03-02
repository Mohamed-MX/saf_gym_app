import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/muscle_wiki_service.dart';
import '../viewmodels/categories_viewmodel.dart';
import '../viewmodels/category_exercises_viewmodel.dart';
import '../widgets/category_card.dart';
import '../widgets/exercise_card.dart';
import '../widgets/shimmer_loading.dart';
import '../theme/app_theme.dart';
import 'exercise_detail_screen.dart';
import 'muscle_selection_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CategoriesViewModel(),
      child: const _CategoriesView(),
    );
  }
}

class _CategoriesView extends StatelessWidget {
  const _CategoriesView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CategoriesViewModel>();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(
          'Categories',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MuscleSelectionScreen(),
                ),
              ),
              icon: const Icon(Icons.accessibility_new_rounded, size: 18),
              label: Text(
                'Muscle Map',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Browse by muscle group',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.mediumGrey,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: vm.categories.length,
                itemBuilder: (context, index) {
                  final category = vm.categories[index];
                  return CategoryCard(
                    name: category.displayName,
                    icon: category.icon,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryExercisesScreen(
                          category: category,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category exercises screen ──────────────────────────────────────────────

class CategoryExercisesScreen extends StatelessWidget {
  final MuscleCategory category;

  const CategoryExercisesScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          CategoryExercisesViewModel()..loadExercises(category.muscleName),
      child: _CategoryExercisesView(category: category),
    );
  }
}

class _CategoryExercisesView extends StatelessWidget {
  final MuscleCategory category;

  const _CategoryExercisesView({required this.category});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CategoryExercisesViewModel>();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(
          category.displayName,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: vm.isLoading
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: List.generate(
                  5,
                  (index) => const ExerciseCardShimmer(),
                ),
              ),
            )
          : vm.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppTheme.mediumGrey),
                      const SizedBox(height: 16),
                      Text(vm.error!,
                          style: const TextStyle(
                              color: AppTheme.darkGrey)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context
                            .read<CategoryExercisesViewModel>()
                            .loadExercises(category.muscleName),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : vm.exercises.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fitness_center,
                            size: 64,
                            color: AppTheme.mediumGrey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No exercises found',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primaryBlue,
                      onRefresh: () => context
                          .read<CategoryExercisesViewModel>()
                          .loadExercises(category.muscleName),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: vm.exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = vm.exercises[index];
                          return ExerciseCard(
                            exercise: exercise,
                            index: index,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ExerciseDetailScreen(
                                        exercise: exercise),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
