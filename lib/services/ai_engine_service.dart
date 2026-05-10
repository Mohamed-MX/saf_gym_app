import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// ── AiDayTarget ───────────────────────────────────────────────────────────────
//
// Fully decoded output from one model prediction.
// Target string format: "muscles | sets | reps | exercise_count | cardio"
// Example:  "Chest, Triceps, Front Shoulders | 3 | 12 | 5 | None"

class AiDayTarget {
  final List<String> muscles;
  final int sets;
  final int reps;
  final int exerciseCount;    // 5 normally, 6 for weight_loss
  final String cardio;        // "None" or "Treadmill"

  bool get hasCardio => cardio != 'None' && cardio.isNotEmpty;

  const AiDayTarget({
    required this.muscles,
    required this.sets,
    required this.reps,
    required this.exerciseCount,
    required this.cardio,
  });
}

// ── AiEngineService ───────────────────────────────────────────────────────────
//
// NEW MODEL — 10 input features:
//   [Goal_Encoded, Level_Encoded, Days_Per_Week, Day_Index,
//    Has_Barbell, Has_BodyOnly, Has_Cable, Has_Dumbbell,
//    Has_Kettlebells, Has_Machine]
//
// Equipment is MULTI-HOT (6 binary flags), not a single integer.
//
// Output: probability distribution over target_mapping classes.
// Target format: "muscles | sets | reps | exercise_count | cardio"

class AiEngineService {
  static final AiEngineService instance = AiEngineService._internal();
  AiEngineService._internal();

  Interpreter? _interpreter;
  Map<String, dynamic>? _mappings;
  bool _isInitialized = false;

  // ── Equipment name → column index in the multi-hot vector ─────────────────
  // MUST match alphabetical order used in Python: Barbell, Body Only, Cable,
  // Dumbbell, Kettlebells, Machine.
  static const Map<String, int> _equipmentIndex = {
    'Barbell'    : 0,
    'Body Only'  : 1,
    'Cable'      : 2,
    'Dumbbell'   : 3,
    'Kettlebells': 4,
    'Machine'    : 5,
  };

  // ── UI label → model category name ────────────────────────────────────────
  static const Map<String, String> _uiToModelEquip = {
    'Barbell'    : 'Barbell',
    'Dumbbells'  : 'Dumbbell',
    'Machines'   : 'Machine',
    'Cables'     : 'Cable',
    'Bodyweight' : 'Body Only',
    'Kettlebells': 'Kettlebells',
  };

  // ── init ───────────────────────────────────────────────────────────────────

  Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      final jsonString = await rootBundle
          .loadString('assets/models/sync_fitness_mappings.json');
      _mappings = jsonDecode(jsonString) as Map<String, dynamic>;
      _interpreter =
          await Interpreter.fromAsset('assets/models/sync_fitness_engine.tflite');
      _isInitialized = true;
      // ignore: avoid_print
      print('✅ AI Engine loaded');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ AI Engine failed to load: $e');
      return false;
    }
  }

  // ── predictDayTarget ───────────────────────────────────────────────────────
  //
  // Parameters
  //   levelName   — "beginner" | "intermediate" | "advanced"
  //   goalName    — "hypertrophy" | "strength" | "weight_loss"
  //   daysPerWeek — total days in the plan (1–7)
  //   dayIndex    — 1-indexed position of this day
  //   uiEquipment — ALL equipment strings selected by the user (UI labels),
  //                 e.g. {"Barbell", "Dumbbells", "Cables"}
  //                 They are multi-hot encoded into 6 binary flags.

  Future<AiDayTarget> predictDayTarget({
    required String levelName,
    required String goalName,
    required int daysPerWeek,
    required int dayIndex,
    required Set<String> uiEquipment,   // ← now the full set, not one item
  }) async {
    if (!_isInitialized) {
      final ok = await init();
      if (!ok) return _fallback(levelName, goalName);
    }

    // ── 1. Encode Goal ────────────────────────────────────────────────────────
    final goalList  = List<String>.from(_mappings!['goal_mapping']  as List);
    final levelList = List<String>.from(_mappings!['level_mapping'] as List);
    final fullTargetList = List<dynamic>.from(_mappings!['target_mapping'] as List);

    int goalEncoded  = goalList.indexOf(goalName.toLowerCase());
    int levelEncoded = levelList.indexOf(levelName.toLowerCase());
    if (goalEncoded  == -1) goalEncoded  = 0;
    if (levelEncoded == -1) levelEncoded = 1; // default intermediate

    // ── 2. Multi-hot encode equipment ─────────────────────────────────────────
    // 6 binary flags: [Has_Barbell, Has_BodyOnly, Has_Cable,
    //                  Has_Dumbbell, Has_Kettlebells, Has_Machine]
    final List<double> equipFlags = List.filled(6, 0.0);
    for (final uiLabel in uiEquipment) {
      final modelName = _uiToModelEquip[uiLabel];
      if (modelName != null) {
        final idx = _equipmentIndex[modelName];
        if (idx != null) equipFlags[idx] = 1.0;
      }
    }

    // ── 3. Build 10-feature input tensor ─────────────────────────────────────
    // [Goal_Encoded, Level_Encoded, Days_Per_Week, Day_Index,
    //  Has_Barbell, Has_BodyOnly, Has_Cable, Has_Dumbbell,
    //  Has_Kettlebells, Has_Machine]
    var input = [[
      goalEncoded.toDouble(),
      levelEncoded.toDouble(),
      daysPerWeek.toDouble(),
      dayIndex.toDouble(),
      equipFlags[0], // Has_Barbell
      equipFlags[1], // Has_BodyOnly
      equipFlags[2], // Has_Cable
      equipFlags[3], // Has_Dumbbell
      equipFlags[4], // Has_Kettlebells
      equipFlags[5], // Has_Machine
    ]];

    // ── 4. Output buffer — MUST match full target list size (inc. any NaN) ───
    final int numClasses = fullTargetList.length;
    var output = List.filled(numClasses, 0.0).reshape([1, numClasses]);

    // ── 5. Run inference ──────────────────────────────────────────────────────
    _interpreter!.run(input, output);

    // ── 6. Pick the winning class (skip NaN / null slots) ────────────────────
    final List<double> probs = List<double>.from(output[0] as List);
    int bestIdx = 0;
    double maxP = -1;
    for (int i = 0; i < probs.length; i++) {
      final entry = fullTargetList[i];
      if (entry == null || entry.toString() == 'NaN') continue;
      if (probs[i] > maxP) { maxP = probs[i]; bestIdx = i; }
    }

    // ── 7. Decode target string ───────────────────────────────────────────────
    // Format: "muscles | sets | reps | exercise_count | cardio"
    final String raw = fullTargetList[bestIdx].toString();
    final List<String> parts = raw.split(' | ');

    final List<String> muscles   = parts.isNotEmpty
        ? parts[0].split(', ').map((m) => m.trim()).toList()
        : ['Chest', 'Lats'];
    final int sets           = parts.length > 1 ? (int.tryParse(parts[1]) ?? 3)  : 3;
    final int reps           = parts.length > 2 ? (int.tryParse(parts[2]) ?? 12) : 12;
    final int exerciseCount  = parts.length > 3 ? (int.tryParse(parts[3]) ?? 5)  : 5;
    final String cardio      = parts.length > 4 ? parts[4].trim() : 'None';

    return AiDayTarget(
      muscles      : muscles,
      sets         : sets,
      reps         : reps,
      exerciseCount: exerciseCount,
      cardio       : cardio,
    );
  }

  // ── Fallback when model cannot load ──────────────────────────────────────
  AiDayTarget _fallback(String levelName, String goalName) {
    final int sets = levelName == 'advanced'     ? 5
                   : levelName == 'intermediate' ? 4 : 3;
    final int reps = levelName == 'advanced'     ? 5
                   : levelName == 'intermediate' ? 8 : 10;
    return AiDayTarget(
      muscles      : ['Chest', 'Lats', 'Biceps', 'Triceps'],
      sets         : sets,
      reps         : reps,
      exerciseCount: goalName == 'weight_loss' ? 6 : 5,
      cardio       : goalName == 'weight_loss' ? 'Treadmill' : 'None',
    );
  }
}