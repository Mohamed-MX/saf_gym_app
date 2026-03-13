part of 'exercise_detail_bloc.dart';

abstract class ExerciseDetailEvent {}

/// Fired when the screen opens with an exercise object.
class ExerciseDetailLoad extends ExerciseDetailEvent {
  final MuscleWikiExercise exercise;
  ExerciseDetailLoad(this.exercise);
}

/// Fired when the user taps an arrow or swipes to a new video page.
class ExerciseDetailVideoPageChanged extends ExerciseDetailEvent {
  final int page;
  ExerciseDetailVideoPageChanged(this.page);
}
