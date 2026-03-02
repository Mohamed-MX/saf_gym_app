import 'package:flutter/foundation.dart';
import '../services/favorites_service.dart';
import '../services/muscle_wiki_service.dart';

class FavoritesViewModel extends ChangeNotifier {
  final FavoritesService _favoritesService = FavoritesService();

  List<MuscleWikiExercise> _exercises = [];
  bool _isLoading = true;

  List<MuscleWikiExercise> get exercises => _exercises;
  bool get isLoading => _isLoading;

  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      _exercises = await _favoritesService.getFavoriteExercises();
    } catch (_) {
      _exercises = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeFavorite(int exerciseId) async {
    await _favoritesService.removeFavorite(exerciseId);
    _exercises.removeWhere((e) => e.id == exerciseId);
    notifyListeners();
  }
}
