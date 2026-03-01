import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/exercise.dart';
import '../services/wger_api_service.dart';
import '../widgets/category_card.dart';
import '../widgets/exercise_card.dart';
import '../widgets/shimmer_loading.dart';
import '../theme/app_theme.dart';
import 'exercise_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final WgerApiService _apiService = WgerApiService();
  List<ExerciseCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openCategory(ExerciseCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryExercisesScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(
          'Categories',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            )
          : Padding(
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
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return CategoryCard(
                          name: category.name,
                          icon: CategoryCard.getCategoryIcon(category.name),
                          onTap: () => _openCategory(category),
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

/// Screen that displays exercises filtered by category
class CategoryExercisesScreen extends StatefulWidget {
  final ExerciseCategory category;

  const CategoryExercisesScreen({super.key, required this.category});

  @override
  State<CategoryExercisesScreen> createState() =>
      _CategoryExercisesScreenState();
}

class _CategoryExercisesScreenState extends State<CategoryExercisesScreen> {
  final WgerApiService _apiService = WgerApiService();
  List<Exercise> _exercises = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final exercises =
          await _apiService.getExercisesByCategory(widget.category.id);
      if (mounted) {
        setState(() {
          _exercises = exercises;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load exercises';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(
          widget.category.name,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: List.generate(
                  5,
                  (index) => const ExerciseCardShimmer(),
                ),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppTheme.mediumGrey),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: TextStyle(color: AppTheme.darkGrey)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadExercises,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _exercises.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fitness_center,
                            size: 64,
                            color: AppTheme.mediumGrey,
                          ),
                          const SizedBox(height: 16),
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
                      onRefresh: _loadExercises,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = _exercises[index];
                          return ExerciseCard(
                            exercise: exercise,
                            index: index,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ExerciseDetailScreen(exercise: exercise),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
