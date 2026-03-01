import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorite_exercises';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Get all favorite exercise IDs
  Future<List<int>> getFavorites() async {
    final prefs = await _prefs;
    final favorites = prefs.getStringList(_favoritesKey) ?? [];
    return favorites.map((id) => int.parse(id)).toList();
  }

  /// Check if an exercise is a favorite
  Future<bool> isFavorite(int exerciseId) async {
    final favorites = await getFavorites();
    return favorites.contains(exerciseId);
  }

  /// Toggle the favorite status of an exercise
  Future<bool> toggleFavorite(int exerciseId) async {
    final prefs = await _prefs;
    final favorites = prefs.getStringList(_favoritesKey) ?? [];
    final idStr = exerciseId.toString();

    if (favorites.contains(idStr)) {
      favorites.remove(idStr);
    } else {
      favorites.add(idStr);
    }

    await prefs.setStringList(_favoritesKey, favorites);
    return favorites.contains(idStr);
  }

  /// Remove a favorite
  Future<void> removeFavorite(int exerciseId) async {
    final prefs = await _prefs;
    final favorites = prefs.getStringList(_favoritesKey) ?? [];
    favorites.remove(exerciseId.toString());
    await prefs.setStringList(_favoritesKey, favorites);
  }
}
