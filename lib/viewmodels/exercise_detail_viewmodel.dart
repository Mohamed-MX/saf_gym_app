import 'package:flutter/foundation.dart';
import '../services/favorites_service.dart';
import '../services/muscle_wiki_service.dart';

class ExerciseDetailViewModel extends ChangeNotifier {
  final FavoritesService _favoritesService = FavoritesService();

  bool _isFavorite = false;
  int _currentImageIndex = 0;

  bool get isFavorite => _isFavorite;
  int get currentImageIndex => _currentImageIndex;

  Future<void> checkFavorite(int exerciseId) async {
    _isFavorite = await _favoritesService.isFavorite(exerciseId);
    notifyListeners();
  }

  /// Toggles favorite and stores the full exercise for offline access.
  /// Returns `true` if the exercise is now favourited.
  Future<bool> toggleFavorite(
    int exerciseId,
    MuscleWikiExercise exercise,
  ) async {
    _isFavorite =
        await _favoritesService.toggleFavorite(exerciseId, exercise);
    notifyListeners();
    return _isFavorite;
  }

  void setImageIndex(int index) {
    _currentImageIndex = index;
    notifyListeners();
  }
}
