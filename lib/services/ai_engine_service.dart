import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class AiEngineService {
  // Singleton pattern so we only load the model once
  static final AiEngineService instance = AiEngineService._internal();
  AiEngineService._internal();

  Interpreter? _interpreter;
  Map<String, dynamic>? _mappings;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Load the dictionary (JSON)
      final jsonString = await rootBundle.loadString('assets/models/sync_fitness_mappings.json');
      _mappings = jsonDecode(jsonString);

      // 2. Load the AI Engine (TFLite)
      _interpreter = await Interpreter.fromAsset('assets/models/sync_fitness_engine.tflite');
      _isInitialized = true;
      print("✅ SYNC FITNESS AI Engine Loaded!");
    } catch (e) {
      print("❌ Failed to load AI: $e");
    }
  }

  /// Runs the AI model for a specific day in the workout plan
  Future<Map<String, dynamic>> predictDayTarget({
    required String levelName, // e.g., "beginner"
    required int daysPerWeek,  // e.g., 3
    required int dayIndex,     // e.g., 1
    required String equipment, // e.g., "Dumbbells"
  }) async {
    if (!_isInitialized) await init();

    // 1. Translate Text to Numbers using the JSON mappings
    int levelEncoded = (_mappings!['level_mapping'] as List).indexOf(levelName.toLowerCase());
    int equipEncoded = (_mappings!['equip_mapping'] as List).indexOf(equipment);

    // Fallbacks just in case the UI sends something unexpected
    if (levelEncoded == -1) levelEncoded = 0; // Default to advanced/beginner based on your map
    if (equipEncoded == -1) equipEncoded = 1; // Default to Body Only

    // 2. Prepare the Input Tensor [[Level, Days, DayIndex, Equipment]]
    var input = [[
      levelEncoded.toDouble(),
      daysPerWeek.toDouble(),
      dayIndex.toDouble(),
      equipEncoded.toDouble()
    ]];

    // 3. Prepare the Output Tensor (Probabilities for all possible outcomes)
    int numClasses = (_mappings!['target_mapping'] as List).length;
    var output = List.filled(1 * numClasses, 0.0).reshape([1, numClasses]);

    // 4. Run the AI!
    _interpreter!.run(input, output);

    // 5. Find the prediction with the highest probability
    List<double> probabilities = output[0];
    int highestIndex = 0;
    double maxProb = probabilities[0];

    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        highestIndex = i;
      }
    }

    // 6. Decode the AI's answer (e.g., "Chest, Lats | 3 | 12")
    String predictedTarget = _mappings!['target_mapping'][highestIndex];
    List<String> parts = predictedTarget.split(" | ");

    // Return the clean data to your app
    return {
      "muscles": parts[0].split(", "), // Turns "Chest, Lats" into ['Chest', 'Lats']
      "sets": int.parse(parts[1]),
      "reps": int.parse(parts[2]),
    };
  }
}