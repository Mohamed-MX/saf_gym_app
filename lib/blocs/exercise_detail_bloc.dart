import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/muscle_wiki_service.dart';
import '../services/saf_database.dart';

part 'exercise_detail_event.dart';
part 'exercise_detail_state.dart';

class ExerciseDetailBloc
    extends Bloc<ExerciseDetailEvent, ExerciseDetailState> {
  final SafDatabase _cacheDb = SafDatabase.instance;
  final MuscleWikiService _service = MuscleWikiService();

  ExerciseDetailBloc() : super(ExerciseDetailInitial()) {
    on<ExerciseDetailLoad>(_onLoad);
    on<ExerciseDetailVideoPageChanged>(_onVideoPageChanged);
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
        emit(ExerciseDetailLoaded(
          exercise: cached,
          currentVideoPage: 0,
        ));
        return;
      }
    } catch (_) {}

    // 2. Cache miss — fetch full exercise from /exercises/{id}
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

    emit(ExerciseDetailLoaded(
      exercise: exercise,
      currentVideoPage: 0,
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
}
