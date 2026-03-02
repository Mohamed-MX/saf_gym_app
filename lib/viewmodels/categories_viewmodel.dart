import 'package:flutter/foundation.dart';
import '../services/muscle_wiki_service.dart';

class CategoriesViewModel extends ChangeNotifier {
  final MuscleWikiService _service = MuscleWikiService();

  List<MuscleCategory> _categories = [];
  final bool _isLoading = false;

  CategoriesViewModel() {
    _loadCategories();
  }

  List<MuscleCategory> get categories => _categories;
  bool get isLoading => _isLoading;

  void _loadCategories() {
    // Categories are built from a static list — no network needed
    _categories = _service.getMuscleCategories();
    notifyListeners();
  }
}
