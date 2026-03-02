import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'muscle_wiki_service.dart';

/// Persists favourite exercises as full JSON so they can be displayed
/// without any network call after the first load.
class FavoritesService {
  static const String _idsKey = 'favorite_exercise_ids';
  static const String _prefix = 'fav_exercise_';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ── Read ────────────────────────────────────────────────────────────────

  Future<List<int>> getFavoriteIds() async {
    final prefs = await _prefs;
    return (prefs.getStringList(_idsKey) ?? [])
        .map(int.parse)
        .toList();
  }

  Future<bool> isFavorite(int exerciseId) async {
    final ids = await getFavoriteIds();
    return ids.contains(exerciseId);
  }

  /// Returns all favourite exercises in the order they were added.
  Future<List<MuscleWikiExercise>> getFavoriteExercises() async {
    final prefs = await _prefs;
    final ids = await getFavoriteIds();
    final result = <MuscleWikiExercise>[];
    for (final id in ids) {
      final raw = prefs.getString('$_prefix$id');
      if (raw != null) {
        try {
          result.add(MuscleWikiExercise.fromJson(jsonDecode(raw)));
        } catch (_) {}
      }
    }
    return result;
  }

  // ── Write ───────────────────────────────────────────────────────────────

  /// Toggles favourite status. Stores the full exercise JSON on add so
  /// the Favourites screen needs no network call.
  /// Returns `true` if the exercise is now a favourite.
  Future<bool> toggleFavorite(
    int exerciseId,
    MuscleWikiExercise exercise,
  ) async {
    final prefs = await _prefs;
    final ids = prefs.getStringList(_idsKey) ?? [];
    final idStr = exerciseId.toString();

    if (ids.contains(idStr)) {
      ids.remove(idStr);
      await prefs.remove('$_prefix$exerciseId');
      await prefs.setStringList(_idsKey, ids);
      return false;
    } else {
      ids.add(idStr);
      await prefs.setString(
          '$_prefix$exerciseId', jsonEncode(exercise.toJson()));
      await prefs.setStringList(_idsKey, ids);
      return true;
    }
  }

  Future<void> removeFavorite(int exerciseId) async {
    final prefs = await _prefs;
    final ids = prefs.getStringList(_idsKey) ?? [];
    ids.remove(exerciseId.toString());
    await prefs.remove('$_prefix$exerciseId');
    await prefs.setStringList(_idsKey, ids);
  }
}
