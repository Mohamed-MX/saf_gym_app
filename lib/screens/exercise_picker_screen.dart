import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/exercise_picker_viewmodel.dart';
import '../services/muscle_wiki_service.dart';
import '../theme/app_theme.dart';

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

class _ExercisePickerView extends StatelessWidget {
  final String targetDay;
  const _ExercisePickerView({required this.targetDay});

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
              targetDay,
              style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
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
      body: Column(
        children: [
          // ── Filter Section ──
          Container(
            color: AppTheme.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: vm.isLoadingFilters
                ? const SizedBox(
                    height: 40,
                    child: Center(child: LinearProgressIndicator(color: AppTheme.primaryBlue)),
                  )
                : Column(
                    children: [
                      // Muscle filter
                      _FilterRow(
                        label: 'Muscle',
                        items: vm.muscles,
                        selected: vm.selectedMuscle,
                        onSelect: (v) => context.read<ExercisePickerViewModel>().setMuscle(v),
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(height: 8),
                      // Equipment filter
                      _FilterRow(
                        label: 'Equipment',
                        items: vm.categories,
                        selected: vm.selectedCategory,
                        onSelect: (v) => context.read<ExercisePickerViewModel>().setCategory(v),
                        color: const Color(0xFF6B4EFF),
                      ),
                      const SizedBox(height: 8),
                      // Difficulty filter
                      _FilterRow(
                        label: 'Difficulty',
                        items: ExercisePickerViewModel.difficulties,
                        selected: vm.selectedDifficulty,
                        onSelect: (v) => context.read<ExercisePickerViewModel>().setDifficulty(v),
                        color: const Color(0xFF00A878),
                      ),
                      // Clear filters
                      if (vm.selectedMuscle != null ||
                          vm.selectedCategory != null ||
                          vm.selectedDifficulty != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                context.read<ExercisePickerViewModel>().clearFilters(),
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
          // ── Exercise List ──
          Expanded(
            child: vm.exercises.isEmpty && !vm.isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.fitness_center, size: 48, color: AppTheme.mediumGrey),
                        const SizedBox(height: 12),
                        Text(
                          'No exercises found',
                          style: TextStyle(color: AppTheme.darkGrey, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              context.read<ExercisePickerViewModel>().clearFilters(),
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollEndNotification &&
                          n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                        context.read<ExercisePickerViewModel>().loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      itemCount: vm.exercises.length + (vm.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == vm.exercises.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.primaryBlue),
                            ),
                          );
                        }
                        final ex = vm.exercises[index];
                        final selected = vm.isSelected(ex.id);
                        return _PickerExerciseCard(
                          exercise: ex,
                          isSelected: selected,
                          onTap: () => context
                              .read<ExercisePickerViewModel>()
                              .toggleSelect(ex),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      // ── Add button ──
      bottomNavigationBar: vm.selectedCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: ElevatedButton(
                  onPressed: () {
                    final exercises = context
                        .read<ExercisePickerViewModel>()
                        .buildPlannedExercises();
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
                    'Add ${vm.selectedCount} exercise${vm.selectedCount != 1 ? 's' : ''} to $targetDay',
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
                // "All" chip
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: selected == null,
                    onSelected: (_) => onSelect(null),
                    selectedColor: color.withValues(alpha: 0.15),
                    checkmarkColor: color,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: selected == null ? color : AppTheme.darkGrey,
                      fontWeight: selected == null ? FontWeight.w700 : FontWeight.normal,
                    ),
                    side: BorderSide(color: selected == null ? color : Colors.transparent),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
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
            // Thumbnail
            ClipRRect(
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
            // Info
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
            // Checkbox
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
