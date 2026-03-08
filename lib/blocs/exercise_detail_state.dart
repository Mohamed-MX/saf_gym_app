part of 'exercise_detail_bloc.dart';

abstract class ExerciseDetailState {}

class ExerciseDetailInitial extends ExerciseDetailState {}

class ExerciseDetailLoaded extends ExerciseDetailState {
  final MuscleWikiExercise exercise;
  final int currentVideoPage;
  final bool isFavorite;

  ExerciseDetailLoaded({
    required this.exercise,
    this.currentVideoPage = 0,
    this.isFavorite = false,
  });

  ExerciseDetailLoaded copyWith({
    MuscleWikiExercise? exercise,
    int? currentVideoPage,
    bool? isFavorite,
  }) {
    return ExerciseDetailLoaded(
      exercise: exercise ?? this.exercise,
      currentVideoPage: currentVideoPage ?? this.currentVideoPage,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
