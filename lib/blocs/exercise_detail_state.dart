part of 'exercise_detail_bloc.dart';

abstract class ExerciseDetailState {}

class ExerciseDetailInitial extends ExerciseDetailState {}

class ExerciseDetailLoaded extends ExerciseDetailState {
  final MuscleWikiExercise exercise;
  final int currentVideoPage;

  ExerciseDetailLoaded({
    required this.exercise,
    this.currentVideoPage = 0,
  });

  ExerciseDetailLoaded copyWith({
    MuscleWikiExercise? exercise,
    int? currentVideoPage,
  }) {
    return ExerciseDetailLoaded(
      exercise: exercise ?? this.exercise,
      currentVideoPage: currentVideoPage ?? this.currentVideoPage,
    );
  }
}
