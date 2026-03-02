import 'package:flutter/foundation.dart';
import '../services/muscle_wiki_service.dart';

class MuscleSelectionViewModel extends ChangeNotifier {
  final MuscleWikiService _service = MuscleWikiService();

  // ── Toggle states ──
  bool _isMale = true;
  bool _isAdvanced = false;
  bool _isFront = true;

  // ── Selected muscles ──
  final Set<String> _selectedMuscles = {};

  // ── Exercise fetch state ──
  List<MuscleWikiExercise> _exercises = [];
  bool _isLoading = false;
  String? _activeMuscleLabel;

  // ── Getters ──
  bool get isMale => _isMale;
  bool get isAdvanced => _isAdvanced;
  bool get isFront => _isFront;
  Set<String> get selectedMuscles => Set.unmodifiable(_selectedMuscles);
  List<MuscleWikiExercise> get exercises => _exercises;
  bool get isLoading => _isLoading;
  String? get activeMuscleLabel => _activeMuscleLabel;

  String get bodyAsset {
    final gender = _isMale ? 'Male' : 'Female';
    final side = _isFront ? 'Front' : 'Back';

    if (_isMale && !_isAdvanced) {
      return 'assets/SVGs/$gender Simple $side.svg';
    }
    if (!_isMale && !_isAdvanced) {
      return 'assets/SVGs/$gender Simple $side.svg';
    }
    if (!_isMale && _isAdvanced) {
      return 'assets/SVGs/Female advanced ${_isFront ? "Front" : "Backsvg"}.svg';
    }
    // Male advanced fallback to simple
    return 'assets/SVGs/Male Simple $side.svg';
  }

  // ── Actions ──
  void setGender(bool isMale) {
    _isMale = isMale;
    _selectedMuscles.clear();
    _exercises = [];
    _activeMuscleLabel = null;
    notifyListeners();
  }

  void setAdvanced(bool isAdvanced) {
    _isAdvanced = isAdvanced;
    notifyListeners();
  }

  void setFront(bool isFront) {
    _isFront = isFront;
    notifyListeners();
  }

  void onMuscleTap(String muscleId, String label) {
    if (_selectedMuscles.contains(muscleId)) {
      _selectedMuscles.remove(muscleId);
      if (_selectedMuscles.isEmpty) {
        _exercises = [];
        _activeMuscleLabel = null;
      }
      notifyListeners();
    } else {
      _selectedMuscles.add(muscleId);
      _activeMuscleLabel = label;
      notifyListeners();
      _fetchExercises(muscleId, label);
    }
  }

  void removeSelectedMuscle(String muscleId) {
    _selectedMuscles.remove(muscleId);
    if (_selectedMuscles.isEmpty) {
      _exercises = [];
      _activeMuscleLabel = null;
    }
    notifyListeners();
  }

  void clearAll() {
    _selectedMuscles.clear();
    _exercises = [];
    _activeMuscleLabel = null;
    notifyListeners();
  }

  Future<void> _fetchExercises(String muscleId, String label) async {
    _isLoading = true;
    notifyListeners();

    final results = await _service.getExercisesByMuscle(
      muscle: muscleId,
    );

    _exercises = results;
    _isLoading = false;
    _activeMuscleLabel = label;
    notifyListeners();
  }
}
