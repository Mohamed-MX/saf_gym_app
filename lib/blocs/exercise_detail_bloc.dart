import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/muscle_wiki_service.dart';
import '../services/favorites_service.dart';
import '../services/exercise_cache_db.dart';

part 'exercise_detail_event.dart';
part 'exercise_detail_state.dart';

class ExerciseDetailBloc
    extends Bloc<ExerciseDetailEvent, ExerciseDetailState> {
  final FavoritesService _favoritesService = FavoritesService();
  final ExerciseCacheDb _cacheDb = ExerciseCacheDb.instance;
  final MuscleWikiService _service = MuscleWikiService();

  ExerciseDetailBloc() : super(ExerciseDetailInitial()) {
    on<ExerciseDetailLoad>(_onLoad);
    on<ExerciseDetailVideoPageChanged>(_onVideoPageChanged);
    on<ExerciseDetailFavoriteToggled>(_onFavoriteToggled);
  }

  Future<void> _onLoad(
    ExerciseDetailLoad event,
    Emitter<ExerciseDetailState> emit,
  ) async {
    MuscleWikiExercise exercise = event.exercise;

    // 1. Check sqflite cache first — instant for repeat visits
    try {
      final cached = await _cacheDb.getExercise(exercise.id);
      if (cached != null && cached.videos.isNotEmpty) {
        exercise = cached;
        final isFavorite = await _favoritesService.isFavorite(exercise.id);
        emit(ExerciseDetailLoaded(
          exercise: exercise,
          currentVideoPage: 0,
          isFavorite: isFavorite,
        ));
        return;
      }
    } catch (_) {}

    // 2. Cache miss — fetch full exercise from /exercises/{id}
    //    (the list endpoint only returns id + name, NOT videos or steps)
    try {
      final full = await _service.getExerciseById(
        exercise.id,
        muscleSlug: exercise.muscleSlug,
      );
      if (full != null) {
        exercise = full;
        // Persist for instant future loads
        await _cacheDb.upsertExercise(exercise);
      }
    } catch (_) {
      // Network failed — fall back to the minimal exercise from the list
    }

    final isFavorite = await _favoritesService.isFavorite(exercise.id);
    emit(ExerciseDetailLoaded(
      exercise: exercise,
      currentVideoPage: 0,
      isFavorite: isFavorite,
    ));
  }

  void _onVideoPageChanged(
    ExerciseDetailVideoPageChanged event,
    Emitter<ExerciseDetailState> emit,
  ) {
    final current = state;
    if (current is ExerciseDetailLoaded) {
      emit(current.copyWith(currentVideoPage: event.page));
    }
  }

  Future<void> _onFavoriteToggled(
    ExerciseDetailFavoriteToggled event,
    Emitter<ExerciseDetailState> emit,
  ) async {
    final current = state;
    if (current is! ExerciseDetailLoaded) return;
    final isNowFavorite = await _favoritesService.toggleFavorite(
      event.exercise.id,
      event.exercise,
    );
    emit(current.copyWith(isFavorite: isNowFavorite));
  }
}
