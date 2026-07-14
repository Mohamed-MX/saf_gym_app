import 'lib/services/muscle_wiki_service.dart';

void main() async {
  final service = MuscleWikiService();
  final exercises = await service.getExercisesFiltered(muscles: ['abdominals'], limit: 5);
  print('Found ${exercises.length} exercises');
  for (var e in exercises) {
    print('- ${e.name} (${e.primaryMuscles}) -> ${e.thumbnailUrl}');
  }
}
