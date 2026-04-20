import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../viewmodels/exercise_picker_viewmodel.dart';
import '../services/muscle_wiki_service.dart';
import '../theme/app_theme.dart';
import 'exercise_detail_screen.dart';

// Mapping of svg muscle group "id" → our asset file for the blue overlay
const _muscleOverlays = <String, String>{
  'abdominals': 'abs simple.svg',
  'obliques': 'Obliques simple.svg',
  'chest': 'chest simple.svg',
  'front-shoulders': 'shoulder simple.svg',
  'biceps': 'Biceps Simple.svg',
  'forearms': 'Forearm Simple.svg',
  'quads': 'thigh simple.svg',
  'calves': 'calf simple.svg',
  'traps': 'traps simple.svg',
  'traps-middle': 'middle traps simple.svg',
  'lats': 'lats simple.svg',
  'rear-shoulders': 'rear delts simple.svg',
  'triceps': 'triceps simple.svg',
  'hamstrings': 'thigh simple.svg',
  'glutes': 'glutes simple.svg',
  'lower-back': 'lower back simple.svg',
};

class _MuscleRegion {
  final String id;
  final String label;
  final bool isFront;
  final Rect hitRect;
  const _MuscleRegion(this.id, this.label, this.isFront, this.hitRect);
}

const _muscleRegions = <_MuscleRegion>[
  _MuscleRegion('abdominals', 'Abs', true, Rect.fromLTWH(0.40, 0.30, 0.18, 0.15)),
  _MuscleRegion('obliques', 'Obliques', true, Rect.fromLTWH(0.35, 0.30, 0.05, 0.16)),
  _MuscleRegion('chest', 'Chest', true, Rect.fromLTWH(0.36, 0.23, 0.28, 0.07)),
  _MuscleRegion('front-shoulders', 'Shoulders', true, Rect.fromLTWH(0.26, 0.22, 0.10, 0.06)),
  _MuscleRegion('biceps', 'Biceps', true, Rect.fromLTWH(0.21, 0.28, 0.12, 0.09)),
  _MuscleRegion('forearms', 'Forearms', true, Rect.fromLTWH(0.10, 0.35, 0.12, 0.10)),
  _MuscleRegion('quads', 'Quads', true, Rect.fromLTWH(0.50, 0.47, 0.18, 0.22)),
  _MuscleRegion('forearms', 'Forearms', true, Rect.fromLTWH(0.78, 0.35, 0.12, 0.10)),
  _MuscleRegion('quads', 'Quads', true, Rect.fromLTWH(0.30, 0.47, 0.18, 0.22)),
  _MuscleRegion('front-shoulders', 'Shoulders', true, Rect.fromLTWH(0.63, 0.22, 0.10, 0.06)),
  _MuscleRegion('biceps', 'Biceps', true, Rect.fromLTWH(0.67, 0.28, 0.12, 0.09)),
  _MuscleRegion('obliques', 'Obliques', true, Rect.fromLTWH(0.60, 0.30, 0.05, 0.16)),
  _MuscleRegion('lats', 'Lats', false, Rect.fromLTWH(0.55, 0.25, 0.13, 0.18)),
  _MuscleRegion('rear-shoulders', 'Rear Delts', false, Rect.fromLTWH(0.26, 0.22, 0.10, 0.06)),
  _MuscleRegion('traps', 'Traps', false, Rect.fromLTWH(0.38, 0.20, 0.24, 0.04)),
  _MuscleRegion('lats', 'Lats', false, Rect.fromLTWH(0.33, 0.25, 0.14, 0.18)),
  _MuscleRegion('lower-back', 'Lower Back', false, Rect.fromLTWH(0.44, 0.34, 0.13, 0.10)),
  _MuscleRegion('glutes', 'Glutes', false, Rect.fromLTWH(0.27, 0.44, 0.46, 0.08)),
  _MuscleRegion('hamstrings', 'Hamstrings', false, Rect.fromLTWH(0.27, 0.53, 0.46, 0.17)),
  _MuscleRegion('calves', 'Calves', false, Rect.fromLTWH(0.28, 0.70, 0.44, 0.14)),
  _MuscleRegion('rear-shoulders', 'Rear Delts', false, Rect.fromLTWH(0.63, 0.22, 0.10, 0.06)),
  _MuscleRegion('triceps', 'Triceps', false, Rect.fromLTWH(0.21, 0.28, 0.12, 0.09)),
  _MuscleRegion('triceps', 'Triceps', false, Rect.fromLTWH(0.67, 0.28, 0.12, 0.09)),
  _MuscleRegion('traps-middle', 'Mid Traps', false, Rect.fromLTWH(0.45, 0.23, 0.10, 0.10)),
];

class ExercisePickerScreen extends StatelessWidget {
  final String targetDay;
  const ExercisePickerScreen({super.key, required this.targetDay});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExercisePickerViewModel(),
      child: _ExercisePickerView(targetDay: targetDay),
    );
  }
}

class _ExercisePickerView extends StatefulWidget {
  final String targetDay;
  const _ExercisePickerView({required this.targetDay});

  @override
  State<_ExercisePickerView> createState() => _ExercisePickerViewState();
}

class _ExercisePickerViewState extends State<_ExercisePickerView> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildGenderToggle({required bool isMale, required VoidCallback onTap}) {
    final trackColor = isMale ? const Color(0xFF4A7FC1) : const Color(0xFFEA6B8A);
    const double trackW = 60;
    const double trackH = 32;
    const double thumbD = 28;
    const double thumbPad = 2;
    final alignment = isMale ? Alignment.centerLeft : Alignment.centerRight;
    final iconData = isMale ? Icons.male : Icons.female;
    final iconColor = isMale ? const Color(0xFF4A7FC1) : const Color(0xFFEA6B8A);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: trackW,
        height: trackH,
        padding: const EdgeInsets.all(thumbPad),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(trackH / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: alignment,
          child: Container(
            width: thumbD,
            height: thumbD,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(iconData, size: 16, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleToggle({required bool value, required Color activeTrackColor, required VoidCallback onTap}) {
    const double trackW = 60;
    const double trackH = 32;
    const double thumbD = 28;
    const double thumbPad = 2;
    final trackColor = value ? activeTrackColor : const Color(0xFF808080);
    final alignment = value ? Alignment.centerRight : Alignment.centerLeft;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: trackW,
        height: trackH,
        padding: const EdgeInsets.all(thumbPad),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(trackH / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: alignment,
          child: Container(
            width: thumbD,
            height: thumbD,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F0F0),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleWithLabel({required Widget toggle, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        toggle,
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.charcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildBodyMap(ExercisePickerViewModel vm) {
    return Center(
      child: AspectRatio(
        aspectRatio: 660 / 1206,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final regions = _muscleRegions.where((r) => r.isFront == vm.isFront).toList();

            return ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SvgPicture.asset(
                    vm.bodyAsset,
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                    ),
                  ),
                  for (final muscleId in vm.selectedMuscles)
                    if (_muscleOverlays.containsKey(muscleId) &&
                        _muscleRegions.any((r) => r.id == muscleId && r.isFront == vm.isFront))
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, _) => Opacity(
                          opacity: _pulseAnim.value,
                          child: SvgPicture.asset(
                            'assets/SVGs/${_muscleOverlays[muscleId]}',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                  ...regions.map((region) {
                    final left = region.hitRect.left * w;
                    final top = region.hitRect.top * h;
                    final rw = region.hitRect.width * w;
                    final rh = region.hitRect.height * h;

                    return Positioned(
                      left: left,
                      top: top,
                      width: rw,
                      height: rh,
                      child: GestureDetector(
                        onTap: () => vm.onMuscleTap(region.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: vm.selectedMuscles.contains(region.id)
                                ? AppTheme.primaryBlue.withValues(alpha: 0.0)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: vm.selectedMuscles.contains(region.id)
                                ? Border.all(
                                    color: AppTheme.primaryBlue.withValues(alpha: 0.0),
                                    width: 2,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExercisePickerViewModel>();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Exercises',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            Text(
              widget.targetDay,
              style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Body Map and Toggles
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 380,
                    child: _buildBodyMap(vm),
                  ),
                  Positioned(
                    top: 0,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToggleWithLabel(
                          toggle: _buildGenderToggle(
                            isMale: vm.isMale,
                            onTap: () => context.read<ExercisePickerViewModel>().setGender(!vm.isMale),
                          ),
                          label: vm.isMale ? 'Male' : 'Female',
                        ),
                        const SizedBox(height: 16),
                        _buildToggleWithLabel(
                          toggle: _buildSimpleToggle(
                            value: !vm.isFront,
                            activeTrackColor: const Color(0xFF4A7FC1),
                            onTap: () => context.read<ExercisePickerViewModel>().setFront(!vm.isFront),
                          ),
                          label: vm.isFront ? 'Front' : 'Back',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Filters
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: vm.isLoadingFilters
                  ? const SizedBox(
                      height: 40,
                      child: Center(child: LinearProgressIndicator(color: AppTheme.primaryBlue)),
                    )
                  : Column(
                      children: [
                        _FilterRow(
                          label: 'Equipment',
                          items: vm.categories,
                          selected: vm.selectedCategory,
                          onSelect: (v) => context.read<ExercisePickerViewModel>().setCategory(v),
                          color: const Color(0xFF6B4EFF),
                        ),
                        const SizedBox(height: 8),
                        _FilterRow(
                          label: 'Difficulty',
                          items: ExercisePickerViewModel.difficulties,
                          selected: vm.selectedDifficulty,
                          onSelect: (v) => context.read<ExercisePickerViewModel>().setDifficulty(v),
                          color: const Color(0xFF00A878),
                        ),
                        if (vm.selectedMuscles.isNotEmpty ||
                            vm.selectedCategory != null ||
                            vm.selectedDifficulty != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => context.read<ExercisePickerViewModel>().clearFilters(),
                              icon: const Icon(Icons.clear_all, size: 16),
                              label: const Text('Clear filters'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.mediumGrey,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),

          // Exercise List
          if (vm.exercises.isEmpty && !vm.isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fitness_center, size: 48, color: AppTheme.mediumGrey),
                    const SizedBox(height: 12),
                    const Text(
                      'No exercises found',
                      style: TextStyle(color: AppTheme.darkGrey, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.read<ExercisePickerViewModel>().clearFilters(),
                      child: const Text('Clear filters'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == vm.exercises.length) {
                      if (vm.isLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                    final ex = vm.exercises[index];
                    final selected = vm.isSelected(ex.id);
                    
                    // Trigger load more when near end
                    if (index == vm.exercises.length - 1 && vm.hasMore) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        context.read<ExercisePickerViewModel>().loadMore();
                      });
                    }

                    return _PickerExerciseCard(
                      exercise: ex,
                      isSelected: selected,
                      onTap: () => context.read<ExercisePickerViewModel>().toggleSelect(ex),
                    );
                  },
                  childCount: vm.exercises.length + (vm.isLoading ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: vm.selectedCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: ElevatedButton(
                  onPressed: () {
                    final exercises = context.read<ExercisePickerViewModel>().buildPlannedExercises();
                    Navigator.pop(context, exercises);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: AppTheme.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Text(
                    'Add ${vm.selectedCount} exercise${vm.selectedCount != 1 ? 's' : ''} to ${widget.targetDay}',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ── Filter Row ────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final String label;
  final List<String> items;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final Color color;

  const _FilterRow({
    required this.label,
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...items.map((item) {
                  final isSelected = selected == item;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(item),
                      selected: isSelected,
                      onSelected: (_) => onSelect(isSelected ? null : item),
                      selectedColor: color.withValues(alpha: 0.15),
                      checkmarkColor: color,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected ? color : AppTheme.darkGrey,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                      side: BorderSide(color: isSelected ? color : Colors.transparent),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Picker Exercise Card ──────────────────────────────────────────────────

class _PickerExerciseCard extends StatelessWidget {
  final MuscleWikiExercise exercise;
  final bool isSelected;
  final VoidCallback onTap;

  const _PickerExerciseCard({
    required this.exercise,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.06)
              : AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected ? [] : AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExerciseDetailScreen(exercise: exercise),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppTheme.radiusMd - 2)),
              child: SizedBox(
                width: 80,
                height: 80,
                child: exercise.displayImageUrl != null
                    ? Image.network(
                        exercise.displayImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, err, _) => Container(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          child: const Icon(Icons.fitness_center,
                              color: AppTheme.primaryBlue),
                        ),
                      )
                    : Container(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        child: const Icon(Icons.fitness_center,
                            color: AppTheme.primaryBlue),
                      ),
              ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.charcoal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (exercise.primaryMuscles.isNotEmpty)
                      Text(
                        exercise.primaryMuscles.join(', '),
                        style: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (exercise.category != null) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B4EFF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          exercise.category!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6B4EFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryBlue : AppTheme.mediumGrey,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, size: 18, color: AppTheme.white)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
