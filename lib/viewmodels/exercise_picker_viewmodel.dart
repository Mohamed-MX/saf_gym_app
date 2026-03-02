import 'package:flutter/foundation.dart';
import '../services/muscle_wiki_service.dart';
import '../models/workout_plan.dart';

class ExercisePickerViewModel extends ChangeNotifier {
  final MuscleWikiService _service = MuscleWikiService();

  // ── Filter state ────────────────────────────────────────────────────────
  String? selectedMuscle;
  String? selectedCategory;
  String? selectedDifficulty;

  // ── Available filter options ─────────────────────────────────────────────
  List<String> muscles = [];
  List<String> categories = [];
  static const List<String> difficulties = [
    'Beginner', 'Intermediate', 'Advanced',
  ];

  // ── Results ──────────────────────────────────────────────────────────────
  List<MuscleWikiExercise> _exercises = [];
  bool _isLoading = false;
  bool _isLoadingFilters = true;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 20;

  // ── Selection ─────────────────────────────────────────────────────────────
  final Set<int> _selectedIds = {};
  final Map<int, MuscleWikiExercise> _selectedExercises = {};

  // ── Getters ──────────────────────────────────────────────────────────────
  List<MuscleWikiExercise> get exercises => _exercises;
  bool get isLoading => _isLoading;
  bool get isLoadingFilters => _isLoadingFilters;
  bool get hasMore => _hasMore;
  Set<int> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;

  bool isSelected(int exerciseId) => _selectedIds.contains(exerciseId);

  ExercisePickerViewModel() {
    Future.microtask(() async {
      await _loadFilterOptions();
      await search();
    });
  }

  // ── Filter options ───────────────────────────────────────────────────────
  Future<void> _loadFilterOptions() async {
    _isLoadingFilters = true;
    notifyListeners();
    final results = await Future.wait([
      _service.getApiMuscles(),
      _service.getApiCategories(),
    ]);
    muscles = results[0];
    categories = results[1];
    _isLoadingFilters = false;
    notifyListeners();
  }

  // ── Search / pagination ──────────────────────────────────────────────────
  Future<void> search() async {
    _exercises = [];
    _offset = 0;
    _hasMore = true;
    await _loadPage();
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    await _loadPage();
  }

  Future<void> _loadPage() async {
    _isLoading = true;
    notifyListeners();

    final page = await _service.getExercisesFiltered(
      muscle: selectedMuscle,
      category: selectedCategory,
      difficulty: selectedDifficulty,
      limit: _pageSize,
      offset: _offset,
    );

    _exercises.addAll(page);
    _offset += page.length;
    _hasMore = page.length == _pageSize;
    _isLoading = false;
    notifyListeners();
  }

  // ── Filter setters ───────────────────────────────────────────────────────
  void setMuscle(String? value) {
    selectedMuscle = value;
    search();
  }

  void setCategory(String? value) {
    selectedCategory = value;
    search();
  }

  void setDifficulty(String? value) {
    selectedDifficulty = value;
    search();
  }

  void clearFilters() {
    selectedMuscle = null;
    selectedCategory = null;
    selectedDifficulty = null;
    search();
  }

  // ── Selection ────────────────────────────────────────────────────────────
  void toggleSelect(MuscleWikiExercise exercise) {
    if (_selectedIds.contains(exercise.id)) {
      _selectedIds.remove(exercise.id);
      _selectedExercises.remove(exercise.id);
    } else {
      _selectedIds.add(exercise.id);
      _selectedExercises[exercise.id] = exercise;
    }
    notifyListeners();
  }

  /// Convert selected exercises to PlannedExercise for the editor
  List<PlannedExercise> buildPlannedExercises() =>
      _selectedExercises.values.map((ex) {
        return PlannedExercise(
          exerciseId: ex.id,
          name: ex.name,
          thumbnailUrl: ex.thumbnailUrl,
          muscleGroup: ex.primaryMuscles.isNotEmpty
              ? ex.primaryMuscles.first
              : null,
        );
      }).toList();
}
