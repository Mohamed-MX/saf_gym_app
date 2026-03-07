import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/muscle_wiki_service.dart';
import '../viewmodels/muscle_selection_viewmodel.dart';

// Mapping of svg muscle group "id" → our asset file for the blue overlay
const _muscleOverlays = <String, String>{
  'abdominals': 'abs simple.svg',
  'obliques': 'abs simple.svg',
  'chest': 'chest simple.svg',
  'front-shoulders': 'shoulder simple.svg',
  'biceps': 'arms simple.svg',
  'forearms': 'arms simple.svg',
  'quads': 'thigh simple.svg',
  'calves': 'calf simple.svg',
  'traps': 'back simple.svg',
  'traps-middle': 'back simple.svg',
  'lats': 'back simple.svg',
  'rear-shoulders': 'shoulder simple.svg',
  'triceps': 'arms simple.svg',
  'hamstrings': 'thigh simple.svg',
  'glutes': 'back simple.svg',
  'lower-back': 'back simple.svg',
};

// ── All clickable muscle regions, with FRONT / BACK side info ──────────────
class _MuscleRegion {
  final String id;
  final String label;
  final bool isFront;
  final Rect hitRect; // normalised 0-1 based on the 660×1206 SVG viewBox
  const _MuscleRegion(this.id, this.label, this.isFront, this.hitRect);
}

const _muscleRegions = <_MuscleRegion>[
  // FRONT side
  _MuscleRegion('abdominals', 'Abs', true, Rect.fromLTWH(0.35, 0.27, 0.30, 0.25)),
  _MuscleRegion('obliques', 'Obliques', true, Rect.fromLTWH(0.23, 0.30, 0.13, 0.18)),
  _MuscleRegion('chest', 'Chest', true, Rect.fromLTWH(0.28, 0.16, 0.44, 0.12)),
  _MuscleRegion('front-shoulders', 'Shoulders', true, Rect.fromLTWH(0.13, 0.14, 0.15, 0.11)),
  _MuscleRegion('biceps', 'Biceps', true, Rect.fromLTWH(0.07, 0.24, 0.12, 0.14)),
  _MuscleRegion('forearms', 'Forearms', true, Rect.fromLTWH(0.04, 0.37, 0.12, 0.12)),
  _MuscleRegion('quads', 'Quads', true, Rect.fromLTWH(0.27, 0.52, 0.46, 0.19)),
  _MuscleRegion('calves', 'Calves', true, Rect.fromLTWH(0.28, 0.79, 0.44, 0.14)),
  // back extras shown on front side (right side of body in svg)
  _MuscleRegion('front-shoulders', 'Shoulders', true, Rect.fromLTWH(0.72, 0.14, 0.15, 0.11)),
  _MuscleRegion('forearms', 'Forearms', true, Rect.fromLTWH(0.84, 0.37, 0.12, 0.12)),
  // BACK side
  _MuscleRegion('traps', 'Traps', false, Rect.fromLTWH(0.28, 0.13, 0.44, 0.09)),
  _MuscleRegion('lats', 'Lats', false, Rect.fromLTWH(0.22, 0.22, 0.56, 0.15)),
  _MuscleRegion('lower-back', 'Lower Back', false, Rect.fromLTWH(0.32, 0.36, 0.36, 0.10)),
  _MuscleRegion('glutes', 'Glutes', false, Rect.fromLTWH(0.27, 0.44, 0.46, 0.12)),
  _MuscleRegion('hamstrings', 'Hamstrings', false, Rect.fromLTWH(0.27, 0.53, 0.46, 0.17)),
  _MuscleRegion('calves', 'Calves', false, Rect.fromLTWH(0.28, 0.79, 0.44, 0.14)),
  _MuscleRegion('rear-shoulders', 'Rear Delts', false, Rect.fromLTWH(0.13, 0.14, 0.15, 0.11)),
  _MuscleRegion('rear-shoulders', 'Rear Delts', false, Rect.fromLTWH(0.72, 0.14, 0.15, 0.11)),
  _MuscleRegion('triceps', 'Triceps', false, Rect.fromLTWH(0.07, 0.24, 0.12, 0.14)),
  _MuscleRegion('triceps', 'Triceps', false, Rect.fromLTWH(0.81, 0.24, 0.12, 0.14)),
  _MuscleRegion('traps-middle', 'Mid Traps', false, Rect.fromLTWH(0.30, 0.20, 0.40, 0.10)),
];

class MuscleSelectionScreen extends StatelessWidget {
  const MuscleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MuscleSelectionViewModel(),
      child: const _MuscleSelectionView(),
    );
  }
}

class _MuscleSelectionView extends StatefulWidget {
  const _MuscleSelectionView();

  @override
  State<_MuscleSelectionView> createState() => _MuscleSelectionViewState();
}

class _MuscleSelectionViewState extends State<_MuscleSelectionView>
    with TickerProviderStateMixin {
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

  // ── Gender toggle (Male/Female) with gender icon in thumb ─────────────────
  // isMale=true → thumb on LEFT, blue background, ♂ icon
  // isMale=false → thumb on RIGHT, pink background, ♀ icon
  Widget _buildGenderToggle({
    required bool isMale,
    required VoidCallback onTap,
  }) {
    // Colors
    final trackColor = isMale
        ? const Color(0xFF4A7FC1)  // blue for male
        : const Color(0xFFEA6B8A); // pink for female

    const double trackW = 72;
    const double trackH = 38;
    const double thumbD = 34;
    const double thumbPad = 2;

    // Thumb alignment: LEFT when male, RIGHT when female
    final alignment = isMale ? Alignment.centerLeft : Alignment.centerRight;

    final iconChar = isMale ? '♂' : '♀';
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
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                iconChar,
                style: TextStyle(
                  fontSize: 18,
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Simple gray toggle (no icon) ────────────────────────────────────────
  // value=false → thumb LEFT, gray track
  // value=true  → thumb RIGHT, blue track
  Widget _buildSimpleToggle({
    required bool value,
    required Color activeTrackColor,
    required VoidCallback onTap,
  }) {
    const double trackW = 72;
    const double trackH = 38;
    const double thumbD = 34;
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
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Toggle + label column ────────────────────────────────────────────────
  Widget _buildToggleWithLabel({
    required Widget toggle,
    required String label,
  }) {
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
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ── Build body diagram with interactive overlay ─────────────────────────
  Widget _buildBodyMap(MuscleSelectionViewModel vm) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final regions = _muscleRegions.where((r) => r.isFront == vm.isFront).toList();

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Base body diagram ──────────────────────────────────────
              SvgPicture.asset(
                vm.bodyAsset,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                ),
              ),

              // ── Blue highlight overlays for selected muscles ────────────
              for (final muscleId in vm.selectedMuscles)
                if (_muscleOverlays.containsKey(muscleId))
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

              // ── Transparent tap targets for each region ────────────────
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
                    onTap: () => vm.onMuscleTap(region.id, region.label),
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
    );
  }

  // ── Selected muscle chips row ──────────────────────────────────────────
  Widget _buildSelectedChips(MuscleSelectionViewModel vm) {
    if (vm.selectedMuscles.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: vm.selectedMuscles.map((id) {
          final name = MuscleWikiService.muscleDisplayNames[id] ?? id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(name,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.white)),
              backgroundColor: AppTheme.primaryBlue,
              deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.white),
              onDeleted: () => vm.removeSelectedMuscle(id),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              side: BorderSide.none,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Exercise card ───────────────────────────────────────────────────────
  Widget _buildExerciseCard(MuscleWikiExercise ex) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Thumbnail / GIF
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusMd),
              bottomLeft: Radius.circular(AppTheme.radiusMd),
            ),
            child: Container(
              width: 80,
              height: 80,
              color: AppTheme.offWhite,
              child: ex.thumbnailUrl != null || ex.gifUrl != null
                  ? Image.network(
                      ex.gifUrl ?? ex.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, trace) => const Icon(
                        Icons.fitness_center,
                        color: AppTheme.primaryBlue,
                        size: 32,
                      ),
                    )
                  : const Icon(
                      Icons.fitness_center,
                      color: AppTheme.primaryBlue,
                      size: 32,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ex.name,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.charcoal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (ex.difficulty != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        ex.difficulty!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                  if (ex.category != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      ex.category!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.chevron_right, color: AppTheme.mediumGrey),
          ),
        ],
      ),
    );
  }

  // ── Exercise list / loading / empty state ───────────────────────────────
  Widget _buildExerciseSection(MuscleSelectionViewModel vm) {
    if (vm.selectedMuscles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.touch_app_rounded,
                size: 48,
                color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Tap a muscle to see exercises',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
      );
    }

    if (vm.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    if (vm.exercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 44, color: AppTheme.mediumGrey.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text(
              'No exercises found',
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${vm.exercises.length} Exercises — ${vm.activeMuscleLabel ?? ""}',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
        ...vm.exercises.map(_buildExerciseCard),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MuscleSelectionViewModel>();

    // Determine label for gender toggle: "Male" when isMale, "Female" when not
    final genderLabel = vm.isMale ? 'Male' : 'Female';
    // Determine label for view toggle: "Front" when isFront, "Back" when not
    final viewLabel = vm.isFront ? 'Front' : 'Back';
    // Determine label for type toggle
    final typeLabel = vm.isAdvanced ? 'Advanced' : 'Simple';

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            snap: true,
            pinned: false,
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: AppTheme.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(
              'Muscle Select',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.white,
              ),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(76),
              child: Container(
                color: AppTheme.primaryBlue,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Gender Toggle ──
                    _buildToggleWithLabel(
                      toggle: _buildGenderToggle(
                        isMale: vm.isMale,
                        onTap: () => context
                            .read<MuscleSelectionViewModel>()
                            .setGender(!vm.isMale),
                      ),
                      label: genderLabel,
                    ),

                    // ── Simple / Advanced Toggle ──
                    _buildToggleWithLabel(
                      toggle: _buildSimpleToggle(
                        value: vm.isAdvanced,
                        activeTrackColor: const Color(0xFF808080),
                        onTap: () => context
                            .read<MuscleSelectionViewModel>()
                            .setAdvanced(!vm.isAdvanced),
                      ),
                      label: typeLabel,
                    ),

                    // ── Front / Back Toggle ──
                    _buildToggleWithLabel(
                      toggle: _buildSimpleToggle(
                        value: !vm.isFront,
                        activeTrackColor: const Color(0xFF4A7FC1),
                        onTap: () => context
                            .read<MuscleSelectionViewModel>()
                            .setFront(!vm.isFront),
                      ),
                      label: viewLabel,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Body map on WHITE background ────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Center(
                  child: SizedBox(
                    height: 420,
                    child: _buildBodyMap(vm),
                  ),
                ),
              ),

              // ── Tap instruction label ──────────────────────────────────
              Container(
                color: AppTheme.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16,
                        color: AppTheme.primaryBlue.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tap muscles on the diagram to select them',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.darkGrey.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    if (vm.selectedMuscles.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            context.read<MuscleSelectionViewModel>().clearAll(),
                        child: Text(
                          'Clear all',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Selected muscle chips ──────────────────────────────────
              if (vm.selectedMuscles.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSelectedChips(vm),
              ],

              const SizedBox(height: 8),

              // ── Exercise section ───────────────────────────────────────
              _buildExerciseSection(vm),
            ],
          ),
        ),
      ),
    );
  }
}
